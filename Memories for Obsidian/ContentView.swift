//
//  ContentView.swift
//  Memories for Obsidian
//
//  Created by Craig Eley on 10/13/25.
//

import SwiftUI
import UniformTypeIdentifiers
import CoreLocation
import MapKit
#if !targetEnvironment(simulator)
import JournalingSuggestions
#endif

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}

struct SavedLocation: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let timestamp: Date

    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double, timestamp: Date = Date()) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

class SavedLocationsManager: ObservableObject {
    static let shared = SavedLocationsManager()

    @Published private(set) var savedLocations: [SavedLocation] = []
    private let userDefaultsKey = "savedLocations"
    private let maxLocations = 15

    private init() {
        loadLocations()
    }

    func saveLocation(name: String, coordinate: CLLocationCoordinate2D) {
        // Check if this location already exists (by name or very close coordinates)
        let isDuplicate = savedLocations.contains { location in
            location.name == name ||
            (abs(location.latitude - coordinate.latitude) < 0.0001 &&
             abs(location.longitude - coordinate.longitude) < 0.0001)
        }

        guard !isDuplicate else { return }

        let newLocation = SavedLocation(
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        // Add to the beginning of the array (most recent first)
        savedLocations.insert(newLocation, at: 0)

        // Keep only the most recent locations
        if savedLocations.count > maxLocations {
            savedLocations = Array(savedLocations.prefix(maxLocations))
        }

        persistLocations()
    }

    func removeLocation(_ location: SavedLocation) {
        savedLocations.removeAll { $0.id == location.id }
        persistLocations()
    }

    private func loadLocations() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let locations = try? JSONDecoder().decode([SavedLocation].self, from: data) else {
            return
        }
        savedLocations = locations
    }

    private func persistLocations() {
        guard let data = try? JSONEncoder().encode(savedLocations) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}

struct MarkdownContent: Identifiable {
    let id = UUID()
    let content: String
    let filename: String
}

struct ContentView: View {
    @StateObject private var suggestionsManager = JournalingSuggestionsManager()
    @StateObject private var locationManager = LocationManager()
    @ObservedObject private var settings = AppSettings.shared
    @State private var markdownToExport: MarkdownContent?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedSuggestion: JournalingSuggestion?
    @State private var userNote: String = ""
    @State private var showNoteInput = false
    @State private var showManualEntry = false
    @State private var manualEntryDate = Date()
    @State private var showLocationPicker = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var selectedPlaceName: String?
    @State private var showSettings = false
    @State private var showOverwriteConfirmation = false
    @State private var pendingMarkdown: String?
    @State private var pendingFileURL: URL?
    @State private var showNoteEditor = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Journal Memories")
                        .font(.largeTitle)
                        .bold()

                    Text("Select a journal suggestion to export as a markdown file for Obsidian.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if let error = suggestionsManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }

                Spacer()

                if showManualEntry {
                    ScrollView {
                        VStack(spacing: 15) {
                            Text("Manual Entry")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                DatePicker("", selection: $manualEntryDate, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                            }
                            .padding(.horizontal)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Location (optional)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Button(action: {
                                    showLocationPicker = true
                                }) {
                                    HStack {
                                        Image(systemName: "location.circle")
                                        if let placeName = selectedPlaceName {
                                            Text(placeName)
                                        } else {
                                            Text("Choose Location")
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(8)
                                }
                                .foregroundColor(.primary)
                            }
                            .padding(.horizontal)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Note (optional)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Button(action: {
                                    showNoteEditor = true
                                }) {
                                    HStack {
                                        Image(systemName: "note.text")
                                        if userNote.isEmpty {
                                            Text("Add Note")
                                        } else {
                                            Text(userNote.prefix(50) + (userNote.count > 50 ? "..." : ""))
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(8)
                                }
                                .foregroundColor(.primary)
                            }
                            .padding(.horizontal)

                            HStack(spacing: 15) {
                                Button(action: {
                                    showManualEntry = false
                                    userNote = ""
                                    manualEntryDate = Date()
                                    selectedLocation = nil
                                    selectedPlaceName = nil
                                }) {
                                    Text("Cancel")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.gray)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }

                                Button(action: {
                                    Task { @MainActor in
                                        await exportManualEntry(note: userNote, date: manualEntryDate, location: selectedLocation, placeName: selectedPlaceName)
                                        showManualEntry = false
                                        userNote = ""
                                        manualEntryDate = Date()
                                        selectedLocation = nil
                                        selectedPlaceName = nil
                                    }
                                }) {
                                    Text("Export")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                } else if showNoteInput {
                    ScrollView {
                        VStack(spacing: 15) {
                            Text("Add a note (optional)")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                Button(action: {
                                    showNoteEditor = true
                                }) {
                                    HStack {
                                        Image(systemName: "note.text")
                                        if userNote.isEmpty {
                                            Text("Add Note")
                                        } else {
                                            Text(userNote.prefix(50) + (userNote.count > 50 ? "..." : ""))
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(8)
                                }
                                .foregroundColor(.primary)
                            }
                            .padding(.horizontal)

                            HStack(spacing: 15) {
                                Button(action: {
                                    showNoteInput = false
                                    selectedSuggestion = nil
                                    userNote = ""
                                }) {
                                    Text("Cancel")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.gray)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }

                                Button(action: {
                                    Task { @MainActor in
                                        if let suggestion = selectedSuggestion {
                                            await exportMemory(suggestion: suggestion, note: userNote)
                                        }
                                        showNoteInput = false
                                        userNote = ""
                                    }
                                }) {
                                    Text("Export")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                } else {
                    VStack(spacing: 15) {
                        #if !targetEnvironment(simulator)
                        JournalingSuggestionsPicker {
                            Label("Select Memory", systemImage: "sparkles")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        } onCompletion: { suggestion in
                            selectedSuggestion = suggestion
                            showNoteInput = true
                        }
                        .padding(.horizontal)
                        #else
                        Text("JournalingSuggestions API is only available on physical devices")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .padding()
                        #endif

                        Button(action: {
                            showManualEntry = true
                        }) {
                            Label("Manual Entry", systemImage: "pencil")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .sheet(item: $markdownToExport) { markdownWrapper in
            DocumentPicker(markdownContent: markdownWrapper.content, filename: markdownWrapper.filename) { result in
                switch result {
                case .success(let url):
                    let displayPath = userFriendlyPath(for: url)
                    alertMessage = "Markdown file saved successfully!\nLocation: \(displayPath)"
                    showAlert = true
                case .failure(let error):
                    alertMessage = "Failed to save markdown file: \(error.localizedDescription)"
                    showAlert = true
                }
                markdownToExport = nil
            }
        }
        .alert("Export Status", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("File Already Exists", isPresented: $showOverwriteConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingMarkdown = nil
                pendingFileURL = nil
            }
            Button("Overwrite", role: .destructive) {
                if let markdown = pendingMarkdown, let fileURL = pendingFileURL {
                    performSave(markdown: markdown, fileURL: fileURL)
                }
                pendingMarkdown = nil
                pendingFileURL = nil
            }
        } message: {
            Text("A file with this name already exists. Do you want to overwrite it?")
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(
                selectedLocation: $selectedLocation,
                selectedPlaceName: $selectedPlaceName,
                currentLocation: locationManager.location
            )
        }
        .sheet(isPresented: $showNoteEditor) {
            NoteEditorView(noteText: $userNote)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private func generateMarkdown(for suggestion: JournalingSuggestion, note: String) async -> String {
        return await MarkdownGenerator.generateMarkdown(
            from: [suggestion],
            suggestionsManager: suggestionsManager,
            userNote: note
        )
    }

    private func exportMemory(suggestion: JournalingSuggestion, note: String) async {
        let markdown = await generateMarkdown(for: suggestion, note: note)

        // Generate filename from suggestion's date using settings
        let date = suggestion.date?.start ?? Date()
        let filename = settings.generateFilename(for: date)

        // Check if we have a default export folder
        if let defaultFolderURL = settings.resolveDefaultExportFolder() {
            // Try to save directly to the default folder
            if saveToDefaultFolder(markdown: markdown, filename: filename, folderURL: defaultFolderURL) {
                return // Successfully saved, no need to show picker
            }
        }

        // No default folder or save failed - show the picker
        markdownToExport = MarkdownContent(content: markdown, filename: filename)
    }

    private func exportManualEntry(note: String, date: Date, location: CLLocationCoordinate2D?, placeName: String?) async {
        // Get weather - use selected location if available, otherwise use current location
        var weatherInfo: WeatherInfo?
        let weatherLocation: CLLocation?

        if let coord = location {
            weatherLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        } else {
            weatherLocation = locationManager.location
        }

        if let loc = weatherLocation {
            weatherInfo = await suggestionsManager.getWeatherForLocation(loc, date: date)
        }

        let markdown = await MarkdownGenerator.generateManualEntryMarkdown(note: note, date: date, weather: weatherInfo, placeName: placeName)

        // Use selected date/time for filename using settings
        let filename = settings.generateFilename(for: date)

        // Check if we have a default export folder
        if let defaultFolderURL = settings.resolveDefaultExportFolder() {
            // Try to save directly to the default folder
            if saveToDefaultFolder(markdown: markdown, filename: filename, folderURL: defaultFolderURL) {
                return // Successfully saved, no need to show picker
            }
        }

        // No default folder or save failed - show the picker
        markdownToExport = MarkdownContent(content: markdown, filename: filename)
    }

    private func saveToDefaultFolder(markdown: String, filename: String, folderURL: URL) -> Bool {
        guard folderURL.startAccessingSecurityScopedResource() else {
            return false
        }

        defer { folderURL.stopAccessingSecurityScopedResource() }

        let fileURL = folderURL.appendingPathComponent(filename)

        // Check if file already exists
        if FileManager.default.fileExists(atPath: fileURL.path) {
            // Store the pending save data
            pendingMarkdown = markdown
            pendingFileURL = fileURL
            showOverwriteConfirmation = true
            return true // Return true to indicate we handled it (will show confirmation)
        }

        // File doesn't exist, save directly
        performSave(markdown: markdown, fileURL: fileURL)
        return true
    }

    private func performSave(markdown: String, fileURL: URL) {
        guard let folderURL = settings.resolveDefaultExportFolder() else {
            alertMessage = "Failed to access default export folder"
            showAlert = true
            return
        }

        guard folderURL.startAccessingSecurityScopedResource() else {
            alertMessage = "Failed to access security-scoped resource"
            showAlert = true
            return
        }

        defer { folderURL.stopAccessingSecurityScopedResource() }

        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            let displayPath = userFriendlyPath(for: fileURL)
            alertMessage = "Markdown file saved successfully!\nLocation: \(displayPath)"
            showAlert = true
        } catch {
            alertMessage = "Failed to save markdown file: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func userFriendlyPath(for url: URL) -> String {
        let path = url.path

        // Replace common iOS paths with user-friendly names
        if path.contains("/com~apple~CloudDocs") {
            return path.replacingOccurrences(of: "/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs", with: "iCloud Drive")
                      .replacingOccurrences(of: "/var/mobile/Library/Mobile Documents/com~apple~CloudDocs", with: "iCloud Drive")
        } else if path.contains("/Documents") {
            // On My iPhone/iPad
            let components = url.pathComponents
            if let docsIndex = components.firstIndex(of: "Documents") {
                let remainingPath = components[(docsIndex + 1)...].joined(separator: "/")
                return "On My iPhone/Documents/\(remainingPath)"
            }
        }

        // Fallback to just the filename if we can't make it friendlier
        return url.lastPathComponent
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let markdownContent: String
    let filename: String
    let onCompletion: (Result<URL, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(markdownContent: markdownContent, filename: filename, onCompletion: onCompletion)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Create the temp file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try markdownContent.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            context.coordinator.handleError(error)
        }

        let picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let markdownContent: String
        let filename: String
        let onCompletion: (Result<URL, Error>) -> Void

        init(markdownContent: String, filename: String, onCompletion: @escaping (Result<URL, Error>) -> Void) {
            self.markdownContent = markdownContent
            self.filename = filename
            self.onCompletion = onCompletion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onCompletion(.success(url))
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // User cancelled, no action needed
        }

        func handleError(_ error: Error) {
            onCompletion(.failure(error))
        }
    }
}

struct IdentifiableMapItem: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
}

struct LocationPickerView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var selectedPlaceName: String?
    let currentLocation: CLLocation?
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var savedLocationsManager = SavedLocationsManager.shared
    @State private var searchText = ""
    @State private var searchResults: [IdentifiableMapItem] = []
    @State private var region: MKCoordinateRegion
    @State private var currentLocationItem: IdentifiableMapItem?
    @State private var showSearchView = false
    @FocusState private var isSearchFocused: Bool

    init(selectedLocation: Binding<CLLocationCoordinate2D?>, selectedPlaceName: Binding<String?>, currentLocation: CLLocation?) {
        self._selectedLocation = selectedLocation
        self._selectedPlaceName = selectedPlaceName
        self.currentLocation = currentLocation

        // Initialize region with current location or default to San Francisco
        if let location = currentLocation {
            _region = State(initialValue: MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        } else {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
    }

    var sortedSavedLocations: [SavedLocation] {
        guard let currentLoc = currentLocation else {
            // If no current location, return sorted by timestamp (most recent first)
            return savedLocationsManager.savedLocations
        }

        // Sort by distance from current location
        return savedLocationsManager.savedLocations.sorted { location1, location2 in
            let loc1 = CLLocation(latitude: location1.latitude, longitude: location1.longitude)
            let loc2 = CLLocation(latitude: location2.latitude, longitude: location2.longitude)
            let distance1 = currentLoc.distance(from: loc1)
            let distance2 = currentLoc.distance(from: loc2)
            return distance1 < distance2
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search button that opens full-screen search
                Button(action: {
                    showSearchView = true
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        Text("Search for a place")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
                }
                .padding()

                Map(position: .constant(.region(region))) {
                    // Show user's current location
                    if let location = currentLocation {
                        Marker("Current Location", systemImage: "location.fill", coordinate: location.coordinate)
                            .tint(.blue)
                    }

                    // Show search results
                    ForEach(searchResults) { item in
                        Marker(item.mapItem.name ?? "Location", coordinate: item.mapItem.placemark.coordinate)
                            .tint(.red)
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .frame(height: 300)

                List {
                    // Show current location option if available
                    if let currentItem = currentLocationItem {
                        Section(header: Text("Current Location")) {
                            Button(action: {
                                selectLocation(coordinate: currentItem.mapItem.placemark.coordinate, name: currentItem.mapItem.name ?? "Current Location")
                            }) {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading) {
                                        Text(currentItem.mapItem.name ?? "Current Location")
                                            .font(.headline)
                                        if let address = currentItem.mapItem.placemark.title {
                                            Text(address)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }

                    // Show saved locations
                    if !savedLocationsManager.savedLocations.isEmpty {
                        Section(header: Text("Saved Locations")) {
                            ForEach(sortedSavedLocations) { location in
                                Button(action: {
                                    selectLocation(coordinate: location.coordinate, name: location.name)
                                }) {
                                    HStack {
                                        Image(systemName: "mappin.circle")
                                            .foregroundColor(.purple)
                                        Text(location.name)
                                            .font(.headline)
                                    }
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSearchView) {
                LocationSearchView(
                    searchText: $searchText,
                    searchResults: $searchResults,
                    region: $region,
                    onSelectLocation: { coordinate, name in
                        selectLocation(coordinate: coordinate, name: name)
                        showSearchView = false
                    }
                )
            }
            .onChange(of: showSearchView) { oldValue, newValue in
                // Clear search when sheet is dismissed
                if !newValue {
                    searchText = ""
                    searchResults = []
                }
            }
            .onAppear {
                // Reverse geocode current location on appear
                if let location = currentLocation {
                    reverseGeocodeCurrentLocation(location)
                }
            }
        }
    }

    private func reverseGeocodeCurrentLocation(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard error == nil, let placemark = placemarks?.first else { return }

            // Create a MKPlacemark from CLPlacemark
            let mkPlacemark = MKPlacemark(placemark: placemark)
            let mapItem = MKMapItem(placemark: mkPlacemark)

            // Set a name for the location
            if let name = placemark.name {
                mapItem.name = name
            } else if let locality = placemark.locality {
                mapItem.name = locality
            } else {
                mapItem.name = "Current Location"
            }

            currentLocationItem = IdentifiableMapItem(mapItem: mapItem)
        }
    }

    private func searchPlaces(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let response = response {
                searchResults = response.mapItems.map { IdentifiableMapItem(mapItem: $0) }
                if let firstItem = response.mapItems.first {
                    let coordinate = firstItem.placemark.coordinate
                    // Validate coordinate before using it
                    if CLLocationCoordinate2DIsValid(coordinate) {
                        region.center = coordinate
                    }
                }
            }
        }
    }

    private func selectLocation(coordinate: CLLocationCoordinate2D, name: String) {
        selectedLocation = coordinate
        selectedPlaceName = name
        savedLocationsManager.saveLocation(name: name, coordinate: coordinate)
        dismiss()
    }
}

struct LocationSearchView: View {
    @Binding var searchText: String
    @Binding var searchResults: [IdentifiableMapItem]
    @Binding var region: MKCoordinateRegion
    let onSelectLocation: (CLLocationCoordinate2D, String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var isSearchPresented = false

    var body: some View {
        NavigationView {
            List {
                if searchResults.isEmpty && !searchText.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            Text("No results found")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                } else {
                    ForEach(searchResults) { item in
                        Button(action: {
                            onSelectLocation(item.mapItem.placemark.coordinate, item.mapItem.name ?? "Unknown")
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.mapItem.name ?? "Unknown")
                                    .font(.headline)
                                if let address = item.mapItem.placemark.title {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "Search for a place")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: searchText) { oldValue, newValue in
                searchPlaces(query: newValue)
            }
            .onAppear {
                // Activate search field when view appears
                isSearchPresented = true
            }
        }
    }

    private func searchPlaces(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let response = response {
                searchResults = response.mapItems.map { IdentifiableMapItem(mapItem: $0) }
            }
        }
    }
}

struct NoteEditorView: View {
    @Binding var noteText: String
    @Environment(\.dismiss) var dismiss
    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $noteText)
                    .focused($isTextEditorFocused)
                    .padding()
                    .font(.body)
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isTextEditorFocused = true
            }
        }
    }
}

#Preview {
    ContentView()
}
