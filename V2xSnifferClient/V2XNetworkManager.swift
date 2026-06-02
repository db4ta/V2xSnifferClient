import Foundation
import CoreLocation
import SwiftUI
import Network
import Combine

enum V2XMessageType: String {
    case cam = "CAM"
    case denm = "DENM"
    case ivim = "IVIM"
    case spatem = "SPATEM"
    case unknown = "UNKNOWN"
}

struct V2XStation: Identifiable {
    let id: UInt32
    var v2xType: V2XMessageType
    var coordinate: CLLocationCoordinate2D
    var heading: Double
    var title: String
    var subtitle: String
    var lastSeen: Date // Für die automatische Bereinigung
    
    var iconName: String {
        switch v2xType {
        case .cam: return "car.fill"
        case .denm: return "exclamationmark.triangle.fill"
        case .spatem: return "circle.fill"
        case .ivim: return "signpost.right.fill"
        default: return "antenna.radiowaves.left.and.right"
        }
    }
    
    var markerColor: Color {
        switch v2xType {
        case .cam: return .blue
        case .denm: return .red
        case .spatem: return .green
        case .ivim: return .orange
        default: return .gray
        }
    }
}

struct V2XServerPayload: Decodable {
    let msgType: String?
    let data: V2XInnerData?
}

struct V2XInnerData: Decodable {
    let id: Int?
    let latitude: Double?
    let longitude: Double?
    let heading: Double?
    let speed: Double?
    let causeCode: Int?
    let currentPhase: String?
    let timeToChange: Int?
}

class V2XNetworkManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @AppStorage("server_ip") var serverIP: String = "192.168.10.181"
    @AppStorage("server_port") var serverPort: Int = 8080
    
    @Published var filterCAM = true
    @Published var filterDENM = true
    @Published var filterSPATEM = true
    @Published var filterIVIM = true
    
    @Published var trackUserLocation = true
    @Published var mapRotationMode = 0
    
    @Published var activeStations: [V2XStation] = []
    @Published var isConnected = false
    @Published var lastReceivedType: String? = nil
    @Published var currentUserLocation: CLLocationCoordinate2D? = nil
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "V2XTCPNetworkQueue")
    private var inputBuffer = Data()
    
    // In-Memory Speicher für alle empfangenen Rohzeilen (für CSV Export)
    private var csvLogLines: [String] = ["Timestamp;MessageType;StationID;Latitude;Longitude;Heading;Speed;Details"]
    
    private var pruneTimer: Timer?
    
    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        return manager
    }()
    
    var filteredStations: [V2XStation] {
        activeStations.filter { station in
            switch station.v2xType {
            case .cam: return filterCAM
            case .denm: return filterDENM
            case .spatem: return filterSPATEM
            case .ivim: return filterIVIM
            case .unknown: return true
            }
        }
    }
    
    override init() {
        super.init()
        DispatchQueue.main.async {
            self.triggerLocationRequest()
            // Startet den Bereinigungs-Timer (sucht jede Sekunde nach inaktiven Stationen)
            self.startPruneTimer()
        }
        connect()
    }
    
    func triggerLocationRequest() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    private func startPruneTimer() {
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            DispatchQueue.main.async {
                // Entfernt alle Stationen, von denen länger als 10 Sekunden kein Paket kam
                let countBefore = self.activeStations.count
                self.activeStations.removeAll { now.timeIntervalSince($0.lastSeen) > 10.0 }
                let removed = countBefore - self.activeStations.count
                if removed > 0 {
                    print("🧹 [Prune] \(removed) Station(en) wegen Inaktivität (>10s) entfernt.")
                }
            }
        }
    }
    
    func exportCSV() -> URL? {
        let csvString = csvLogLines.joined(separator: "\n")
        let fileName = "V2X_Log_\(Int(Date().timeIntervalSince1970)).csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("❌ CSV Schreibfehler: \(error.localizedDescription)")
            return nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.currentUserLocation = location.coordinate
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    func connect() {
        let nwHost = NWEndpoint.Host(serverIP)
        let nwPort = NWEndpoint.Port(rawValue: UInt16(serverPort))!
        connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.inputBuffer.removeAll()
                    self?.receiveData()
                case .failed, .cancelled:
                    self?.isConnected = false
                default: break
                }
            }
        }
        connection?.start(queue: queue)
    }
    
    func reconnect() {
        connection?.cancel()
        connect()
    }
    
    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                self.inputBuffer.append(data)
                self.processBuffer()
            }
            if error == nil && !isComplete { self.receiveData() }
        }
    }
    
    private func processBuffer() {
        if let _ = inputBuffer.firstIndex(of: 0x0A) {
            while let index = inputBuffer.firstIndex(of: 0x0A) {
                let lineData = inputBuffer.prefix(upTo: index)
                inputBuffer.removeSubrange(..<(index + 1))
                if !lineData.isEmpty { self.parseV2XData(lineData) }
            }
        } else if inputBuffer.count > 20 {
            let snapshot = inputBuffer
            inputBuffer.removeAll()
            self.parseV2XData(snapshot)
        }
    }
    
    private func parseV2XData(_ data: Data) {
        // Für CSV Aufbereitung
        let rawJsonString = String(data: data, encoding: .utf8) ?? ""
        
        do {
            let decoder = JSONDecoder()
            let wrapper = try decoder.decode(V2XServerPayload.self, from: data)
            guard let innerData = wrapper.data, let lat = innerData.latitude, let lon = innerData.longitude else { return }
            let typeString = wrapper.msgType?.uppercased() ?? "UNKNOWN"
            let msgType = V2XMessageType(rawValue: typeString) ?? .unknown
            let sId = UInt32(innerData.id ?? Int.random(in: 1000...9999))
            let coords = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let head = innerData.heading ?? 0.0
            let speed = innerData.speed ?? 0.0
            
            let title = "\(typeString) (ID: \(sId))"
            var subtitle = "C-ITS Station"
            var details = ""
            
            switch msgType {
            case .cam:
                subtitle = "\(Int(speed * 3.6)) km/h"
            case .denm:
                if let code = innerData.causeCode {
                    subtitle = "GEFAHR! Code: \(code)"
                    details = "CauseCode: \(code)"
                }
            case .spatem:
                if let phase = innerData.currentPhase {
                    subtitle = "Ampel: \(phase.uppercased())"
                    details = "Phase: \(phase)"
                }
            default: break
            }
            
            // Log-Zeile für CSV-Export generieren
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let csvLine = "\(timestamp);\(typeString);\(sId);\(lat);\(lon);\(head);\(speed);\(details)"
            
            DispatchQueue.main.async {
                self.csvLogLines.append(csvLine)
                self.lastReceivedType = typeString
                
                if let index = self.activeStations.firstIndex(where: { $0.id == sId }) {
                    // Update der Station inklusive Aktualisierung des Inaktivitäts-Zeitstempels
                    self.activeStations[index].coordinate = coords
                    self.activeStations[index].v2xType = msgType
                    self.activeStations[index].heading = head
                    self.activeStations[index].title = title
                    self.activeStations[index].subtitle = subtitle
                    self.activeStations[index].lastSeen = Date()
                } else {
                    // Neue Station einpflegen
                    self.activeStations.append(V2XStation(id: sId, v2xType: msgType, coordinate: coords, heading: head, title: title, subtitle: subtitle, lastSeen: Date()))
                }
            }
        } catch {}
    }
}
