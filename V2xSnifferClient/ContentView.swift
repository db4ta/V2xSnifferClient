//
//  ContentView.swift
//  V2xSnifferClient
//
//  Created by Alex on 23.05.26.
//

import SwiftUI
import MapKit
import Network
import CoreLocation
import AVFoundation

// MARK: - CoreLocation Equatable Extension
extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MARK: - App-Einstellungen (Persistenz über UserDefaults)

@Observable
public class V2XSettings {
    public static let shared = V2XSettings()
    
    // Netzwerk-Konfiguration
    public var serverIP: String {
        didSet { UserDefaults.standard.set(serverIP, forKey: "v2x_server_ip") }
    }
    public var serverPort: String {
        didSet { UserDefaults.standard.set(serverPort, forKey: "v2x_server_port") }
    }
    public var autoReconnect: Bool {
        didSet { UserDefaults.standard.set(autoReconnect, forKey: "v2x_auto_reconnect") }
    }
    
    // Karten-Konfiguration
    public var mapStyle: String {
        didSet { UserDefaults.standard.set(mapStyle, forKey: "v2x_map_style") }
    }
    public var showsTraffic: Bool {
        didSet { UserDefaults.standard.set(showsTraffic, forKey: "v2x_shows_traffic") }
    }
    public var showsBuildings: Bool {
        didSet { UserDefaults.standard.set(showsBuildings, forKey: "v2x_shows_buildings") }
    }
    public var trackingMode: String {
        didSet { UserDefaults.standard.set(trackingMode, forKey: "v2x_tracking_mode") }
    }
    public var defaultZoomDelta: Double {
        didSet { UserDefaults.standard.set(defaultZoomDelta, forKey: "v2x_zoom_delta") }
    }
    
    // V2X-Darstellung
    public var historyLength: Int {
        didSet { UserDefaults.standard.set(historyLength, forKey: "v2x_history_length") }
    }
    public var dangerZoneOpacity: Double {
        didSet { UserDefaults.standard.set(dangerZoneOpacity, forKey: "v2x_danger_zone_opacity") }
    }
    public var scaleFactor: Double {
        didSet { UserDefaults.standard.set(scaleFactor, forKey: "v2x_scale_factor") }
    }
    public var showVehicleSpeedAnnotation: Bool {
        didSet { UserDefaults.standard.set(showVehicleSpeedAnnotation, forKey: "v2x_show_speed_anno") }
    }
    
    // Sicherheitswarnungen & Audio
    public var speechAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(speechAlertsEnabled, forKey: "v2x_speech_alerts") }
    }
    public var speechRate: Float {
        didSet { UserDefaults.standard.set(speechRate, forKey: "v2x_speech_rate") }
    }
    public var brakeAlertSoundEnabled: Bool {
        didSet { UserDefaults.standard.set(brakeAlertSoundEnabled, forKey: "v2x_brake_sound") }
    }
    
    // GLOSA Parameter
    public var maxGlosaSpeed: Double {
        didSet { UserDefaults.standard.set(maxGlosaSpeed, forKey: "v2x_max_glosa_speed") }
    }
    public var safetyOffsetSeconds: Int {
        didSet { UserDefaults.standard.set(safetyOffsetSeconds, forKey: "v2x_safety_offset") }
    }
    
    private init() {
        self.serverIP = UserDefaults.standard.string(forKey: "v2x_server_ip") ?? "192.168.2.1"
        self.serverPort = UserDefaults.standard.string(forKey: "v2x_server_port") ?? "8080"
        self.autoReconnect = UserDefaults.standard.bool(forKey: "v2x_auto_reconnect")
        
        self.mapStyle = UserDefaults.standard.string(forKey: "v2x_map_style") ?? "Standard"
        self.showsTraffic = UserDefaults.standard.bool(forKey: "v2x_shows_traffic")
        self.showsBuildings = UserDefaults.standard.object(forKey: "v2x_shows_buildings") as? Bool ?? true
        self.trackingMode = UserDefaults.standard.string(forKey: "v2x_tracking_mode") ?? "FollowHeading"
        self.defaultZoomDelta = UserDefaults.standard.double(forKey: "v2x_zoom_delta") == 0.0 ? 0.005 : UserDefaults.standard.double(forKey: "v2x_zoom_delta")
        
        self.historyLength = UserDefaults.standard.object(forKey: "v2x_history_length") as? Int ?? 15
        self.dangerZoneOpacity = UserDefaults.standard.object(forKey: "v2x_danger_zone_opacity") as? Double ?? 0.15
        self.scaleFactor = UserDefaults.standard.object(forKey: "v2x_scale_factor") as? Double ?? 1.0
        self.showVehicleSpeedAnnotation = UserDefaults.standard.object(forKey: "v2x_show_speed_anno") as? Bool ?? true
        
        self.speechAlertsEnabled = UserDefaults.standard.object(forKey: "v2x_speech_alerts") as? Bool ?? true
        self.speechRate = UserDefaults.standard.object(forKey: "v2x_speech_rate") as? Float ?? 0.5
        self.brakeAlertSoundEnabled = UserDefaults.standard.object(forKey: "v2x_brake_sound") as? Bool ?? true
        
        self.maxGlosaSpeed = UserDefaults.standard.object(forKey: "v2x_max_glosa_speed") as? Double ?? 50.0
        self.safetyOffsetSeconds = UserDefaults.standard.object(forKey: "v2x_safety_offset") as? Int ?? 15
    }
}

// MARK: - Datenmodelle

public struct V2XVehicle: Identifiable, Equatable {
    public let id: Int
    public var coordinate: CLLocationCoordinate2D
    public var heading: Double
    public var speed: Double
    public var isBraking: Bool
    public var history: [CLLocationCoordinate2D]
    
    public static func == (lhs: V2XVehicle, rhs: V2XVehicle) -> Bool {
        return lhs.id == rhs.id &&
               lhs.coordinate == rhs.coordinate &&
               lhs.heading == rhs.heading &&
               lhs.speed == rhs.speed &&
               lhs.isBraking == rhs.isBraking
    }
}

public struct V2XDangerZone: Identifiable, Equatable {
    public let id: Int
    public let type: String
    public var coordinate: CLLocationCoordinate2D
    public let radiusMeter: Double
    
    public static func == (lhs: V2XDangerZone, rhs: V2XDangerZone) -> Bool {
        return lhs.id == rhs.id &&
               lhs.type == rhs.type &&
               lhs.coordinate == rhs.coordinate &&
               lhs.radiusMeter == rhs.radiusMeter
    }
}

public struct V2XTrafficLight: Identifiable, Equatable {
    public let id: Int
    public var coordinate: CLLocationCoordinate2D
    public var currentPhase: String
    public var timeToChange: Int
    
    public static func == (lhs: V2XTrafficLight, rhs: V2XTrafficLight) -> Bool {
        return lhs.id == rhs.id &&
               lhs.coordinate == rhs.coordinate &&
               lhs.currentPhase == rhs.currentPhase &&
               lhs.timeToChange == rhs.timeToChange
    }
}

// MARK: - Audio & Sprachausgabe Manager

public class V2XAlertManager {
    public static let shared = V2XAlertManager()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var spokenDangerIDs: Set<Int> = []
    
    private init() {}
    
    public func speak(_ text: String) {
        guard V2XSettings.shared.speechAlertsEnabled else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
        utterance.rate = V2XSettings.shared.speechRate
        
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        speechSynthesizer.speak(utterance)
    }
    
    public func playBrakeChime() {
        guard V2XSettings.shared.brakeAlertSoundEnabled else { return }
        AudioServicesPlaySystemSound(1016) // Subtiler System-Tweakton
    }
    
    public func processDangerSpeech(id: Int, type: String, distance: Int) {
        if !spokenDangerIDs.contains(id) {
            spokenDangerIDs.insert(id)
            speak("Achtung, vorausliegende \(type) in \(distance) Metern.")
        }
    }
    
    public func resetDangerLogs() {
        spokenDangerIDs.removeAll()
    }
}

// MARK: - Netzwerk-Client (TCP) mit Telemetrie & Fehleranalyse

public enum V2XConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case waiting(String)
    case failed(String)
}

@Observable
public class V2XNetClient {
    public var vehicles: [Int: V2XVehicle] = [:]
    public var dangerZones: [Int: V2XDangerZone] = [:]
    public var trafficLights: [Int: V2XTrafficLight] = [:]
    public var myLocation: CLLocationCoordinate2D?
    public var isConnected = false
    
    // Erweiterte Diagnostik
    public var connectionState: V2XConnectionState = .disconnected
    public var diagnosticLogs: [String] = []
    public var bytesReceived: Int64 = 0
    public var packetsPerSecond: Int = 0
    public var latestPayloads: [String] = []
    public var isWifiSatisfied = false
    
    private var connection: NWConnection?
    private var isRunning = false
    private var packetCountThisSecond = 0
    private var telemetryTimer: Timer?
    private var pathMonitor: NWPathMonitor?
    
    public init() {
        startTelemetryTimer()
        startPathMonitoring()
        logDiag("[Client] V2X Client initialisiert. Warte auf Benutzeraktion.")
    }
    
    private func logDiag(_ msg: String) {
        DispatchQueue.main.async {
            let timestamp = Date().formatted(.dateTime.hour().minute().second())
            self.diagnosticLogs.insert("[\(timestamp)] \(msg)", at: 0)
            if self.diagnosticLogs.count > 50 { self.diagnosticLogs.removeLast() }
        }
    }
    
    private func startTelemetryTimer() {
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.packetsPerSecond = self.packetCountThisSecond
            self.packetCountThisSecond = 0
        }
    }
    
    private func startPathMonitoring() {
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isWifiSatisfied = path.usesInterfaceType(.wifi) && path.status == .satisfied
                self.logDiag("[Path] Netzwerkpfad aktualisiert. WiFi aktiv: \(self.isWifiSatisfied), Status: \(path.status)")
            }
        }
        pathMonitor?.start(queue: DispatchQueue.global(qos: .background))
    }
    
    public func connect() {
        guard connection == nil else { return }
        
        let settings = V2XSettings.shared
        let portValue = UInt16(settings.serverPort) ?? 8080
        guard let port = NWEndpoint.Port(rawValue: portValue) else {
            self.connectionState = .failed("Ungültiger Port")
            return
        }
        let host = NWEndpoint.Host(settings.serverIP)
        
        logDiag("[TCP] Starte Verbindungsaufbau zu \(settings.serverIP):\(settings.serverPort)...")
        self.connectionState = .connecting
        
        // TCP-Parameters für schnellen Failover konfigurieren
        let tcpParams = NWParameters.tcp
        tcpParams.requiredInterfaceType = .wifi // Erfordert explizit WiFi zur Fahrzeug-Kopplung
        
        connection = NWConnection(host: host, port: port, using: tcpParams)
        
        connection?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .setup:
                self.logDiag("[TCP State] Setup...")
            case .preparing:
                self.logDiag("[TCP State] Bereite Verbindung vor...")
            case .ready:
                DispatchQueue.main.async {
                    self.isConnected = true
                    self.connectionState = .connected
                    self.logDiag("[TCP State] Bereit! Datenstrom gestartet.")
                    V2XAlertManager.shared.speak("Verbindung mit V 2 X Server hergestellt.")
                }
                self.startReceiving()
            case .waiting(let error):
                let explanation = self.explainError(error)
                DispatchQueue.main.async {
                    self.connectionState = .waiting(explanation)
                    self.logDiag("[TCP State] Wartend: \(explanation) (Code: \(error.localizedDescription))")
                }
            case .failed(let error):
                let explanation = self.explainError(error)
                DispatchQueue.main.async {
                    self.connectionState = .failed(explanation)
                    self.logDiag("[TCP State] Fehler: \(explanation)")
                }
                self.disconnect()
                if V2XSettings.shared.autoReconnect {
                    self.autoReconnect()
                }
            case .cancelled:
                DispatchQueue.main.async {
                    self.connectionState = .disconnected
                    self.logDiag("[TCP State] Verbindung manuell abgebrochen.")
                }
                self.disconnect()
            @unknown default:
                break
            }
        }
        
        isRunning = true
        connection?.start(queue: .global(qos: .userInteractive))
    }
    
    private func explainError(_ error: NWError) -> String {
        switch error {
        case .posix(let code):
            switch code {
            case .ECONNREFUSED: // 61
                return "POSIX 61: Verbindung verweigert. Der Server läuft nicht auf dem konfigurierten Port."
            case .EHOSTUNREACH: // 65
                return "POSIX 65: Host nicht erreichbar. Falsche IP oder Geräte sind nicht im selben WLAN-Subnetz."
            case .ETIMEDOUT: // 60
                return "POSIX 60: Zeitüberschreitung. Prüfen Sie Firewall- und Port-Zuweisung."
            case .ENETDOWN: // 50
                return "POSIX 50: Netzwerk down. Schalten Sie das iPhone-WLAN an und koppeln Sie es mit dem Gateway."
            case .EPERM, .EACCES:
                return "POSIX 1: Zugriff verweigert. Bitte erlauben Sie 'Lokales Netzwerk' in den iOS App-Einstellungen."
            default:
                return "POSIX Fehler \(code.rawValue): \(error.localizedDescription)"
            }
        case .dns(let dnsError):
            return "DNS-Fehler: \(dnsError)"
        default:
            // Fehler -65555 deutet fast immer auf fehlende iOS Local Network Permissions hin
            if error.localizedDescription.contains("-65555") {
                return "iOS Local-Network-Sperre aktiv. App-Berechtigung unter iOS-Einstellungen -> Datenschutz prüfen!"
            }
            return error.localizedDescription
        }
    }
    
    public func disconnect() {
        isRunning = false
        connection?.cancel()
        connection = nil
        DispatchQueue.main.async {
            self.isConnected = false
            if case .connected = self.connectionState {
                self.connectionState = .disconnected
            }
        }
    }
    
    private func autoReconnect() {
        guard isRunning else { return }
        logDiag("[TCP] Versuche automatische Wiederverbindung in 3 Sekunden...")
        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.connect()
        }
    }
    
    private func startReceiving() {
        var remainder = Data()
        
        func next() {
            guard isRunning, let conn = connection else { return }
            conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, complete, error in
                guard let self = self else { return }
                
                if let data = data, !data.isEmpty {
                    self.bytesReceived += Int64(data.count)
                    remainder.append(data)
                    
                    while let idx = remainder.firstIndex(of: 0x0A) {
                        let lineData = remainder.subdata(in: 0..<idx)
                        remainder.removeSubrange(0...idx)
                        if let jsonStr = String(data: lineData, encoding: .utf8) {
                            self.packetCountThisSecond += 1
                            self.parse(jsonStr)
                        }
                    }
                }
                
                if complete || error != nil {
                    self.logDiag("[TCP] Datenstrom beendet oder Fehler empfangen.")
                    self.disconnect()
                } else if self.isRunning {
                    next()
                }
            }
        }
        next()
    }
    
    private func parse(_ str: String) {
        // Telemetrie JSON Log
        DispatchQueue.main.async {
            self.latestPayloads.insert("[\(Date().formatted(.dateTime.hour().minute().second()))] \(str.trimmingCharacters(in: .whitespacesAndNewlines))", at: 0)
            if self.latestPayloads.count > 40 {
                self.latestPayloads.removeLast()
            }
        }
        
        guard let data = str.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["msgType"] as? String,
              let payload = json["data"] as? [String: Any] else { return }
        
        DispatchQueue.main.async {
            switch type {
            case "CAM":
                guard let id = payload["id"] as? Int,
                      let lat = payload["latitude"] as? Double,
                      let lon = payload["longitude"] as? Double else { return }
                
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                var history = self.vehicles[id]?.history ?? []
                history.append(coord)
                
                let maxLen = V2XSettings.shared.historyLength
                if history.count > maxLen {
                    history.removeFirst(history.count - maxLen)
                }
                
                let isBraking = payload["isBraking"] as? Bool ?? false
                if isBraking && !(self.vehicles[id]?.isBraking ?? false) {
                    V2XAlertManager.shared.playBrakeChime()
                }
                
                withAnimation(.linear(duration: 0.25)) {
                    self.vehicles[id] = V2XVehicle(
                        id: id,
                        coordinate: coord,
                        heading: payload["heading"] as? Double ?? 0.0,
                        speed: payload["speed"] as? Double ?? 0.0,
                        isBraking: isBraking,
                        history: history
                    )
                }
                
            case "DENM":
                guard let id = payload["id"] as? Int,
                      let lat = payload["latitude"] as? Double,
                      let lon = payload["longitude"] as? Double else { return }
                
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let typeText = payload["type"] as? String ?? "Gefahr"
                
                // Audio-Warnungs-Berechnung bei neu empfangener DENM
                if let myLoc = self.myLocation {
                    let distance = self.haversineDistance(from: myLoc, to: coordinate)
                    if distance < 500 {
                        V2XAlertManager.shared.processDangerSpeech(id: id, type: typeText, distance: Int(distance))
                    }
                }
                
                withAnimation(.easeInOut) {
                    self.dangerZones[id] = V2XDangerZone(
                        id: id,
                        type: typeText,
                        coordinate: coordinate,
                        radiusMeter: payload["radiusMeter"] as? Double ?? 100.0
                    )
                }
                
            case "SPATEM":
                guard let id = payload["id"] as? Int,
                      let lat = payload["latitude"] as? Double,
                      let lon = payload["longitude"] as? Double else { return }
                
                withAnimation(.easeInOut) {
                    self.trafficLights[id] = V2XTrafficLight(
                        id: id,
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        currentPhase: payload["currentPhase"] as? String ?? "red",
                        timeToChange: payload["timeToChange"] as? Int ?? 0
                    )
                }
                
            case "MY_GPS":
                guard let lat = payload["latitude"] as? Double,
                      let lon = payload["longitude"] as? Double else { return }
                
                withAnimation(.easeInOut) {
                    self.myLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                
            default:
                break
            }
        }
    }
    
    // Hilfsfunktion: Haversine Distanz
    private func haversineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let dLat = (to.latitude - from.latitude) * .pi / 180.0
        let dLon = (to.longitude - from.longitude) * .pi / 180.0
        let a = sin(dLat / 2.0) * sin(dLat / 2.0) +
                cos(from.latitude * .pi / 180.0) * cos(to.latitude * .pi / 180.0) *
                sin(dLon / 2.0) * sin(dLon / 2.0)
        return 6371000.0 * (2.0 * atan2(sqrt(a), sqrt(1.0 - a)))
    }
    
    // MATHEMATISCHE GLOSA-BERECHNUNG (Grüne Welle Assistent)
    public func calculateGlosa(for light: V2XTrafficLight) -> Int? {
        guard let myLoc = myLocation else { return nil }
        
        let distance = haversineDistance(from: myLoc, to: light.coordinate)
        
        if distance > 400.0 || distance < 10.0 || light.timeToChange <= 0 { return nil }
        
        let targetSpeed = (distance / Double(light.timeToChange)) * 3.6
        let maxLimit = V2XSettings.shared.maxGlosaSpeed
        let safetyOffset = V2XSettings.shared.safetyOffsetSeconds
        
        if light.currentPhase == "green" {
            return targetSpeed <= maxLimit ? Int(targetSpeed) : Int((distance / Double(light.timeToChange + safetyOffset)) * 3.6)
        } else {
            return targetSpeed <= (maxLimit + 10.0) ? Int(targetSpeed) : nil
        }
    }
}

// MARK: - Benutzeroberfläche (UI)

struct ContentView: View {
    @State private var client = V2XNetClient()
    @State private var settings = V2XSettings.shared
    
    // Voreingestellter App-Start in Stuttgart, Deutschland (48.7758, 9.1829)
    @State private var mapPosition: MapCameraPosition = .userLocation(fallback: .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.7758, longitude: 9.1829),
        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    )))
    @State private var showSettings = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // MapKit Karte
            Map(position: $mapPosition) {
                // Eigene GPS-Position (vom Mac-Server gestreamt)
                if let loc = client.myLocation {
                    Annotation("Mein Auto", coordinate: loc) {
                        ZStack {
                            Circle().fill(.white).frame(width: 18 * settings.scaleFactor, height: 18 * settings.scaleFactor)
                            Circle().fill(.green).frame(width: 12 * settings.scaleFactor, height: 12 * settings.scaleFactor)
                        }
                        .shadow(radius: 4)
                    }
                }
                
                // DENM Warnzonen
                ForEach(Array(client.dangerZones.values)) { danger in
                    MapCircle(center: danger.coordinate, radius: danger.radiusMeter)
                        .foregroundStyle(.red.opacity(settings.dangerZoneOpacity))
                        .stroke(.red, lineWidth: 2.0)
                    
                    Annotation(danger.type, coordinate: danger.coordinate, anchor: .bottom) {
                        VStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 16 * settings.scaleFactor))
                            Text(danger.type)
                                .font(.system(size: 9 * settings.scaleFactor))
                                .bold()
                                .padding(4)
                                .background(Color(.systemBackground).opacity(0.8))
                                .cornerRadius(4)
                        }
                    }
                }
                
                // CAM Fahrzeuge
                ForEach(Array(client.vehicles.values)) { vehicle in
                    if vehicle.history.count > 1 {
                        MapPolyline(coordinates: vehicle.history)
                            .stroke(vehicle.isBraking ? Color.red : Color.blue, lineWidth: 3.0)
                    }
                    
                    Annotation("Vehicle \(vehicle.id)", coordinate: vehicle.coordinate) {
                        VStack(spacing: 2) {
                            Image(systemName: "car.up.fill")
                                .foregroundColor(vehicle.isBraking ? .red : .blue)
                                .font(.system(size: 16 * settings.scaleFactor))
                                .rotationEffect(.degrees(vehicle.heading))
                            
                            if settings.showVehicleSpeedAnnotation {
                                Text("\(Int(vehicle.speed)) km/h")
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(2)
                                    .background(Color(.systemBackground).opacity(0.8))
                                    .cornerRadius(3)
                            }
                        }
                    }
                }
                
                // SPATEM Ampelanlagen mit GLOSA-Assistent
                ForEach(Array(client.trafficLights.values)) { light in
                    Annotation("Ampel", coordinate: light.coordinate) {
                        VStack(spacing: 4) {
                            if let speed = client.calculateGlosa(for: light), speed > 10, speed < Int(settings.maxGlosaSpeed) {
                                Text("\(speed) km/h")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(4)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .shadow(radius: 2)
                            }
                            
                            ZStack {
                                Circle()
                                    .fill(.black)
                                    .frame(width: 32, height: 32)
                                Circle()
                                    .stroke(colorForPhase(light.currentPhase), lineWidth: 4.0)
                                    .frame(width: 28, height: 28)
                                Text("\(light.timeToChange)s")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            .mapStyle(getMapStyle())
            .onChange(of: client.myLocation) { _, newLoc in
                updateCameraPosition(for: newLoc)
            }
            
            // Floating Live Map-Zentrierungs- und Ausrichtungssteuerungen (Rechte Seite)
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // 1. Ausrichtungs- & Tracking-Toggel
                        Button(action: {
                            cycleTrackingMode()
                        }) {
                            Image(systemName: getTrackingIconName())
                                .font(.title3)
                                .foregroundColor(.primary)
                                .frame(width: 48, height: 48)
                                .background(Color(.systemBackground).opacity(0.9))
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        
                        // 2. Schnell-Zentrierer (wird nur angezeigt, wenn kein Tracking aktiv ist und GPS vorhanden ist)
                        if settings.trackingMode == "None" && client.myLocation != nil {
                            Button(action: {
                                settings.trackingMode = "Follow"
                                updateCameraPosition(for: client.myLocation)
                            }) {
                                Image(systemName: "location.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                    .frame(width: 48, height: 48)
                                    .background(Color(.systemBackground).opacity(0.9))
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                        }
                        
                        // 3. Schneller Kartenstil-Umschalter (Standard, Satellit, Hybrid)
                        Button(action: {
                            cycleMapStyle()
                        }) {
                            Image(systemName: "square.3.layers.3d")
                                .font(.title3)
                                .foregroundColor(.primary)
                                .frame(width: 48, height: 48)
                                .background(Color(.systemBackground).opacity(0.9))
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 80)
                }
                Spacer()
            }
            
            // Cockpit Steuerungs-HUD (Unten)
            VStack {
                HStack {
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .padding(12)
                            .background(Color(.systemBackground).opacity(0.9))
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                    Spacer()
                    
                    // Verbindungsindikator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(connectionColor)
                            .frame(width: 8, height: 8)
                        Text(connectionLabel)
                            .font(.caption)
                            .bold()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(20)
                    .shadow(radius: 2)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                Spacer()
                
                // Status Bar am unteren Bildschirmrand
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("V2X LIVE MONITORING - STUTTGART EDGE")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.secondary)
                        Text("Ziele: \(client.vehicles.count) PKW | \(client.trafficLights.count) LSA")
                            .font(.subheadline)
                            .bold()
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground).opacity(0.95))
                .cornerRadius(12)
                .shadow(radius: 5)
                .padding()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(client: client)
        }
        .onAppear {
            client.connect()
        }
        .onDisappear {
            client.disconnect()
        }
    }
    
    private var connectionColor: Color {
        switch client.connectionState {
        case .connected: return .green
        case .connecting: return .yellow
        case .waiting: return .orange
        case .failed: return .red
        case .disconnected: return .gray
        }
    }
    
    private var connectionLabel: String {
        switch client.connectionState {
        case .connected: return "C-ITS Online"
        case .connecting: return "Verbinde..."
        case .waiting: return "Warte auf Pfad"
        case .failed: return "Kopplung gescheitert"
        case .disconnected: return "Trennt"
        }
    }
    
    private func colorForPhase(_ phase: String) -> Color {
        switch phase.lowercased() {
        case "green": return .green
        case "yellow": return .yellow
        default: return .red
        }
    }
    
    private func getMapStyle() -> MapStyle {
        switch settings.mapStyle {
        case "Satellit":
            return .imagery
        case "Hybrid":
            return .hybrid(elevation: settings.showsBuildings ? .realistic : .flat, showsTraffic: settings.showsTraffic)
        default:
            return .standard(elevation: settings.showsBuildings ? .realistic : .flat, showsTraffic: settings.showsTraffic)
        }
    }
    
    private func updateCameraPosition(for coordinate: CLLocationCoordinate2D?) {
        guard let loc = coordinate else { return }
        
        withAnimation {
            switch settings.trackingMode {
            case "FollowHeading":
                mapPosition = .camera(MapCamera(
                    centerCoordinate: loc,
                    distance: 1000,
                    pitch: 45
                ))
            case "Follow":
                mapPosition = .region(MKCoordinateRegion(
                    center: loc,
                    span: MKCoordinateSpan(latitudeDelta: settings.defaultZoomDelta, longitudeDelta: settings.defaultZoomDelta)
                ))
            default:
                break
            }
        }
    }
    
    // Hilfsfunktion: Umschalten des Tracking-Modus
    private func cycleTrackingMode() {
        switch settings.trackingMode {
        case "FollowHeading":
            settings.trackingMode = "Follow"
            V2XAlertManager.shared.speak("Kartenmodus 2 D eingenordet")
        case "Follow":
            settings.trackingMode = "None"
            V2XAlertManager.shared.speak("Kartenmodus freie Bewegung")
        default:
            settings.trackingMode = "FollowHeading"
            V2XAlertManager.shared.speak("Kartenmodus 3 D Fahrtrichtung")
        }
        updateCameraPosition(for: client.myLocation)
    }
    
    private func getTrackingIconName() -> String {
        switch settings.trackingMode {
        case "FollowHeading":
            return "location.north.line.fill" // Kompass / 3D Fahrtrichtung
        case "Follow":
            return "location.fill" // Zentrierter GPS-Pfeil
        default:
            return "location.slash" // Keine Nachführung
        }
    }
    
    // Hilfsfunktion: Kartenstil schnell wechseln
    private func cycleMapStyle() {
        switch settings.mapStyle {
        case "Standard":
            settings.mapStyle = "Satellit"
        case "Satellit":
            settings.mapStyle = "Hybrid"
        default:
            settings.mapStyle = "Standard"
        }
    }
}

// MARK: - Einstellungen-Sheet Hauptmenü

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    var client: V2XNetClient
    @State private var settings = V2XSettings.shared
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Infrastruktur-Kopplung")) {
                    NavigationLink {
                        NetworkView(client: client)
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Netzwerk-Verbindung")
                                Text("\(settings.serverIP):\(settings.serverPort)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "wifi.route")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Section(header: Text("Visualisierung & HUD")) {
                    NavigationLink {
                        MapViewConfigView()
                    } label: {
                        Label("Karten-Optionen", systemImage: "map")
                            .foregroundColor(.green)
                    }
                    
                    NavigationLink {
                        V2XVisualsConfigView()
                    } label: {
                        Label("V2X-Elemente-Darstellung", systemImage: "car.2")
                            .foregroundColor(.orange)
                    }
                }
                
                Section(header: Text("Fahrzeug-Assistenten")) {
                    NavigationLink {
                        SafetyAlertsView()
                    } label: {
                        Label("Sicherheit & Audio", systemImage: "speaker.wave.3")
                            .foregroundColor(.red)
                    }
                    
                    NavigationLink {
                        GlosaTargetConfigView()
                    } label: {
                        Label("Grüne Welle (GLOSA)", systemImage: "waveform.path.ecg")
                            .foregroundColor(.teal)
                    }
                }
                
                Section(header: Text("Echtzeit-Debugging")) {
                    NavigationLink {
                        DiagnosticsView(client: client)
                    } label: {
                        Label("Rohdaten-Terminal", systemImage: "terminal")
                            .foregroundColor(.indigo)
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 1. NetworkView (Sub-View) mit Trouble-Shooting-Terminal

struct NetworkView: View {
    @Bindable var client: V2XNetClient
    @State private var settings = V2XSettings.shared
    
    var body: some View {
        Form {
            Section(header: Text("Server-Kopplung")) {
                HStack {
                    Text("Mac-Server IP")
                    Spacer()
                    TextField("IP-Adresse", text: $settings.serverIP)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numbersAndPunctuation)
                }
                HStack {
                    Text("TCP-Port")
                    Spacer()
                    TextField("8080", text: $settings.serverPort)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
                Toggle("Automatisch wiederverbinden", isOn: $settings.autoReconnect)
            }
            
            Section(header: Text("Kopplungs-Prüfung & Diagnose")) {
                HStack {
                    Text("iPhone WLAN aktiv?")
                    Spacer()
                    Image(systemName: client.isWifiSatisfied ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(client.isWifiSatisfied ? .green : .red)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aktueller Socket-Zustand")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    switch client.connectionState {
                    case .disconnected:
                        Text("Getrennt.")
                            .foregroundColor(.gray).bold()
                    case .connecting:
                        Text("Verbindung wird aufgebaut...")
                            .foregroundColor(.yellow).bold()
                    case .connected:
                        Text("Erfolgreich gekoppelt! Empfange Daten.")
                            .foregroundColor(.green).bold()
                    case .waiting(let reason):
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wartend...")
                                .foregroundColor(.orange).bold()
                            Text(reason)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    case .failed(let errorMsg):
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fehler beim Verbindungsaufbau:")
                                .foregroundColor(.red).bold()
                            Text(errorMsg)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Fehlerbehebung (Troubleshooting)")) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Subnetz-Check", systemImage: "network")
                        .font(.subheadline).bold()
                    Text("Stellen Sie sicher, dass das iPhone im selben WLAN-Netzwerk angemeldet ist wie die Mac-Zentrale. Die IP-Adressen müssen aus demselben IP-Bereich stammen (z. B. 192.168.2.X).")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Label("Lokales Netzwerk zulassen", systemImage: "hand.raised.fill")
                        .font(.subheadline).bold()
                    Text("Wenn iOS blockiert, öffnen Sie die iPhone-App 'Einstellungen' -> 'Datenschutz & Sicherheit' -> 'Lokales Netzwerk' und stellen Sie sicher, dass das Häkchen für 'V2xSnifferClient' gesetzt ist.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Label("Mac-Server prüfen", systemImage: "laptopcomputer")
                        .font(.subheadline).bold()
                    Text("Verifizieren Sie auf dem Mac-Terminal oder in der Mac-Zentrale, ob der TCP-Server auf Port 8080 aktiv geschaltet ist und eingehende Verbindungen akzeptiert.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Verbindungsschreiber (Logs)")) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(client.diagnosticLogs, id: \.self) { log in
                            Text(log)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .frame(height: 120)
            }
            
            Section {
                Button(client.isConnected ? "Manuell trennen" : "Verbindung herstellen") {
                    if client.isConnected {
                        client.disconnect()
                    } else {
                        client.connect()
                    }
                }
                .foregroundColor(client.isConnected ? .red : .blue)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Netzwerk-Konfiguration")
    }
}

// MARK: - 2. MapViewConfigView (Sub-View)

struct MapViewConfigView: View {
    @State private var settings = V2XSettings.shared
    
    let mapStyles = ["Standard", "Satellit", "Hybrid"]
    let trackingModes = [
        "FollowHeading": "Fahrtrichtung (3D)",
        "Follow": "Zentriert (2D)",
        "None": "Statisch (Frei bewegen)"
    ]
    
    var body: some View {
        Form {
            Section(header: Text("Karten-Stil")) {
                Picker("Kartentyp", selection: $settings.mapStyle) {
                    ForEach(mapStyles, id: \.self) { style in
                        Text(style).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                
                Toggle("Echtzeit-Verkehrslage", isOn: $settings.showsTraffic)
                Toggle("3D-Gebäude anzeigen", isOn: $settings.showsBuildings)
            }
            
            Section(header: Text("Kameraausrichtung & Verfolgung")) {
                Picker("Kamera-Modus", selection: $settings.trackingMode) {
                    ForEach(trackingModes.keys.sorted(), id: \.self) { key in
                        Text(trackingModes[key] ?? "").tag(key)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Zoom-Level (Delta)")
                        Spacer()
                        Text(String(format: "%.4f", settings.defaultZoomDelta))
                            .font(.system(.subheadline, design: .monospaced))
                    }
                    Slider(value: $settings.defaultZoomDelta, in: 0.001...0.02, step: 0.001)
                }
                .disabled(settings.trackingMode == "FollowHeading")
            }
        }
        .navigationTitle("Karten-Optionen")
    }
}

// MARK: - 3. V2XVisualsConfigView (Sub-View)

struct V2XVisualsConfigView: View {
    @State private var settings = V2XSettings.shared
    
    var body: some View {
        Form {
            Section(header: Text("Fahrzeuge (CAM)")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Spuren-Historie (Schleppkurve)")
                        Spacer()
                        Text("\(settings.historyLength) Punkte")
                            .bold()
                    }
                    Slider(value: Binding(
                        get: { Double(settings.historyLength) },
                        set: { settings.historyLength = Int($0) }
                    ), in: 1...30, step: 1)
                }
                
                Toggle("Fahrzeug-Geschwindigkeiten anzeigen", isOn: $settings.showVehicleSpeedAnnotation)
            }
            
            Section(header: Text("Gefahrenbereiche (DENM)")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Warnkreis-Deckkraft")
                        Spacer()
                        Text("\(Int(settings.dangerZoneOpacity * 100))%")
                    }
                    Slider(value: $settings.dangerZoneOpacity, in: 0.05...0.6, step: 0.05)
                }
            }
            
            Section(header: Text("Grafische Skalierung")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("UI Elementgröße")
                        Spacer()
                        Text(String(format: "%.1fx", settings.scaleFactor))
                    }
                    Slider(value: $settings.scaleFactor, in: 0.8...2.0, step: 0.1)
                }
            }
        }
        .navigationTitle("V2X-Elemente")
    }
}

// MARK: - 4. SafetyAlertsView (Sub-View)

struct SafetyAlertsView: View {
    @State private var settings = V2XSettings.shared
    
    var body: some View {
        Form {
            Section(header: Text("C-ITS Gefahrenwarnungen (DENM)")) {
                Toggle("Sprachausgabe (Text-to-Speech)", isOn: $settings.speechAlertsEnabled)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Sprechgeschwindigkeit")
                        Spacer()
                        Text(String(format: "%.1fx", settings.speechRate * 2.0))
                    }
                    Slider(value: $settings.speechRate, in: 0.3...0.7, step: 0.05)
                }
                .disabled(!settings.speechAlertsEnabled)
            }
            
            Section(header: Text("Kollisions- & Bremswarnungen")) {
                Toggle("Gong bei plötzlicher Bremsung", isOn: $settings.brakeAlertSoundEnabled)
                
                if settings.brakeAlertSoundEnabled {
                    Text("Ein dezenter Warnsound wird ausgelöst, sobald der C-ITS-Empfänger das Bremslicht-Bit eines vorausfahrenden Fahrzeugs empfängt.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Button("Test-Sprachausgabe abspielen") {
                    V2XAlertManager.shared.speak("Test der akustischen Gefahrenmeldung. System bereit.")
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Sicherheit & Audio")
    }
}

// MARK: - 5. GlosaTargetConfigView (Sub-View)

struct GlosaTargetConfigView: View {
    @State private var settings = V2XSettings.shared
    
    var body: some View {
        Form {
            Section(header: Text("Grüne Welle Berater Parameter")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Maximal zulässige Geschwindigkeit")
                        Spacer()
                        Text("\(Int(settings.maxGlosaSpeed)) km/h")
                            .bold()
                    }
                    Slider(value: $settings.maxGlosaSpeed, in: 30...80, step: 5)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Sicherheitspuffer (Rotphase)")
                        Spacer()
                        Text("\(settings.safetyOffsetSeconds)s")
                            .bold()
                    }
                    Slider(value: Binding(
                        get: { Double(settings.safetyOffsetSeconds) },
                        set: { settings.safetyOffsetSeconds = Int($0) }
                    ), in: 5...25, step: 1)
                }
            }
            
            Section(header: Text("Info")) {
                Text("Die GLOSA-Berechnung (Green Light Optimal Speed Advisory) ermittelt die Geschwindigkeit, mit der Sie fahren müssen, um die Kreuzung ohne Halt während der Grünphase zu passieren.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("GLOSA-Parameter")
    }
}

// MARK: - 6. DiagnosticsView (Sub-View)

struct DiagnosticsView: View {
    var client: V2XNetClient
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Echtzeit-Empfangsdaten")
                    .font(.headline)
                Spacer()
                Button("Verlauf leeren") {
                    client.latestPayloads.removeAll()
                }
                .font(.caption)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            
            if client.latestPayloads.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "opticaldisc")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(client.isConnected ? 360 : 0))
                        .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: client.isConnected)
                    Text("Warte auf Datenpakete...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(client.latestPayloads, id: \.self) { payload in
                            Text(payload)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.85))
                                .cornerRadius(4)
                        }
                    }
                    .padding()
                }
                .background(Color.black)
            }
        }
        .navigationTitle("Diagnose")
    }
}

// MARK: - SwiftUI Preview

#Preview {
    ContentView()
}
