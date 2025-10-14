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

                        TextEditor(text: $userNote)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
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
                    }
                } else if showNoteInput {
                    VStack(spacing: 15) {
                        Text("Add a note (optional)")
                            .font(.headline)

                        TextEditor(text: $userNote)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
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
                    alertMessage = "Markdown file saved successfully!\nLocation: \(url.path)"
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
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(
                selectedLocation: $selectedLocation,
                selectedPlaceName: $selectedPlaceName,
                currentLocation: locationManager.location
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private func generateMarkdown(for suggestion: JournalingSuggestion, note: String) async -> String {
        let markdown = await MarkdownGenerator.generateMarkdown(
            from: [suggestion],
            suggestionsManager: suggestionsManager,
            userNote: note
        )
        print("Generated markdown length: \(markdown.count)")
        print("Markdown content preview: \(String(markdown.prefix(200)))")
        return markdown
    }

    private func exportMemory(suggestion: JournalingSuggestion, note: String) async {
        let markdown = await generateMarkdown(for: suggestion, note: note)
        print("ContentView: Generated markdown length: \(markdown.count)")

        // Generate filename from suggestion's date using settings
        let date = suggestion.date?.start ?? Date()
        let filename = settings.generateFilename(for: date)

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
        print("ContentView: Generated manual entry markdown length: \(markdown.count)")

        // Use selected date/time for filename using settings
        let filename = settings.generateFilename(for: date)

        markdownToExport = MarkdownContent(content: markdown, filename: filename)
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
        // Check if we have a default export folder
        if let defaultFolderURL = AppSettings.shared.resolveDefaultExportFolder() {
            // Try to save directly to the default folder
            if context.coordinator.saveToDefaultFolder(defaultFolderURL) {
                // If successful, we still need to return a picker, but we'll dismiss it immediately
                // Create a dummy picker that we'll cancel
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                let picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
                picker.delegate = context.coordinator

                // Dismiss immediately since we already saved
                DispatchQueue.main.async {
                    picker.dismiss(animated: false)
                }

                return picker
            }
        }

        // No default folder or save failed - show the picker
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        print("DocumentPicker: About to write markdown of length: \(markdownContent.count)")
        print("DocumentPicker: Content preview: \(String(markdownContent.prefix(200)))")

        do {
            try markdownContent.write(to: tempURL, atomically: true, encoding: .utf8)
            print("DocumentPicker: Successfully wrote to temp file at: \(tempURL.path)")

            // Verify the file was written
            if let readBack = try? String(contentsOf: tempURL, encoding: .utf8) {
                print("DocumentPicker: Verified file content length: \(readBack.count)")
            }
        } catch {
            print("DocumentPicker: Error writing file: \(error)")
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

        func saveToDefaultFolder(_ folderURL: URL) -> Bool {
            guard folderURL.startAccessingSecurityScopedResource() else {
                print("Failed to access security-scoped resource")
                return false
            }

            defer { folderURL.stopAccessingSecurityScopedResource() }

            let fileURL = folderURL.appendingPathComponent(filename)

            do {
                try markdownContent.write(to: fileURL, atomically: true, encoding: .utf8)
                print("Successfully saved to default folder: \(fileURL.path)")
                onCompletion(.success(fileURL))
                return true
            } catch {
                print("Failed to save to default folder: \(error)")
                return false
            }
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
    @State private var searchText = ""
    @State private var searchResults: [IdentifiableMapItem] = []
    @State private var region: MKCoordinateRegion

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

    var body: some View {
        NavigationView {
            VStack {
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

                List(searchResults) { item in
                    Button(action: {
                        selectedLocation = item.mapItem.placemark.coordinate
                        selectedPlaceName = item.mapItem.name
                        dismiss()
                    }) {
                        VStack(alignment: .leading) {
                            Text(item.mapItem.name ?? "Unknown")
                                .font(.headline)
                            if let address = item.mapItem.placemark.title {
                                Text(address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search for a place")
                .onChange(of: searchText) { oldValue, newValue in
                    searchPlaces(query: newValue)
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
                    region.center = firstItem.placemark.coordinate
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
