import SwiftUI
import MapKit

@main
struct V2xSnifferClientApp: App {
    @StateObject private var networkManager = V2XNetworkManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView(networkManager: networkManager)
        }
    }
}

struct ContentView: View {
    @ObservedObject var networkManager: V2XNetworkManager
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            Map(position: $position, interactionModes: .all) {
                UserAnnotation()
                
                if let userCoord = networkManager.currentUserLocation {
                    Annotation("Meine Position (Live)", coordinate: userCoord) {
                        ZStack {
                            Circle().fill(Color.white).frame(width: 22, height: 22)
                            Circle().fill(Color.blue).frame(width: 16, height: 16)
                        }
                        .shadow(radius: 4)
                    }
                }
                
                ForEach(networkManager.filteredStations) { station in
                    Annotation(station.title, coordinate: station.coordinate) {
                        V2XIconView(station: station)
                    }
                }
            }
            .mapStyle(.standard)
            .onChange(of: networkManager.trackUserLocation) { _ in updateMapMode() }
            .onChange(of: networkManager.mapRotationMode) { _ in updateMapMode() }
            
            VStack {
                HStack {
                    HStack {
                        Circle()
                            .fill(networkManager.isConnected ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        Text("\(networkManager.serverIP):\(String(networkManager.serverPort))")
                            .font(.system(.caption, design: .monospaced))
                            .bold()
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    
                    Spacer()
                    
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                Spacer()
                
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Button(action: { zoomToFitAll() }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.primary)
                                .padding(10)
                                .background(.thinMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }
                        
                        Button(action: { centerOnUser() }) {
                            Image(systemName: "location.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.blue)
                                .padding(10)
                                .background(.thinMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 30)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(networkManager: networkManager)
        }
    }
    
    private func updateMapMode() {
        if networkManager.trackUserLocation {
            position = networkManager.mapRotationMode == 1 ? .userLocation(followsHeading: true, fallback: .automatic) : .userLocation(followsHeading: false, fallback: .automatic)
        } else {
            position = .automatic
        }
    }
    
    private func centerOnUser() {
        networkManager.triggerLocationRequest()
        if let userCoord = networkManager.currentUserLocation {
            withAnimation {
                position = .region(MKCoordinateRegion(center: userCoord, latitudinalMeters: 500, longitudinalMeters: 500))
            }
        } else {
            withAnimation { position = .userLocation(fallback: .automatic) }
        }
    }
    
    private func zoomToFitAll() {
        var coordinates = networkManager.filteredStations.map { $0.coordinate }
        if let userCoord = networkManager.currentUserLocation {
            coordinates.append(userCoord)
        }
        
        guard !coordinates.isEmpty else { return }
        
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLon = longitudes.min(), let maxLon = longitudes.max() else { return }
        
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.4 + 0.005, longitudeDelta: (maxLon - minLon) * 1.4 + 0.005)
        
        withAnimation {
            position = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
}

struct SettingsView: View {
    @ObservedObject var networkManager: V2XNetworkManager
    @Environment(\.dismiss) var dismiss
    @State private var csvURL: URL?
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Verbindung (Mac-Sniffer)")) {
                    TextField("Server IP", text: $networkManager.serverIP)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Port", value: $networkManager.serverPort, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                    Button("Verbindung neu starten") {
                        networkManager.reconnect()
                        dismiss()
                    }
                }
                
                Section(header: Text("Datenexport")) {
                    Button(action: {
                        if let url = networkManager.exportCSV() {
                            csvURL = url
                            showShareSheet = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            Text("V2X Log als CSV exportieren")
                        }
                    }
                }
                
                Section(header: Text("Kartensteuerung")) {
                    Toggle("Karte folgt eigener Position", isOn: $networkManager.trackUserLocation)
                    Picker("Kartenausrichtung", selection: $networkManager.mapRotationMode) {
                        Text("Fest nach Norden").tag(0)
                        Text("In Fahrtrichtung (Heading)").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("C-ITS Nachrichtenfilter")) {
                    Toggle("CAM anzeigen", isOn: $networkManager.filterCAM)
                    Toggle("DENM anzeigen", isOn: $networkManager.filterDENM)
                    Toggle("SPATEM anzeigen", isOn: $networkManager.filterSPATEM)
                    Toggle("IVIM anzeigen", isOn: $networkManager.filterIVIM)
                }
            }
            .navigationTitle("V2X Einstellungen")
            .navigationBarItems(trailing: Button("Fertig") { dismiss() })
            .sheet(isPresented: $showShareSheet) {
                if let url = csvURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
}

// Hilfskomponente für das iOS-Teilen-Menü
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct V2XIconView: View {
    let station: V2XStation
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(station.markerColor).frame(width: 36, height: 36).shadow(radius: 3)
                Image(systemName: station.iconName)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold))
                    .rotationEffect(.degrees(station.v2xType == .cam ? station.heading : 0))
            }
            Text(station.subtitle)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.white.opacity(0.9)).cornerRadius(4).shadow(radius: 1)
        }
    }
}
