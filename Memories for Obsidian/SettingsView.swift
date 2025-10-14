//
//  SettingsView.swift
//  Memories for Obsidian
//
//  Created by Craig Eley on 10/13/25.
//

import SwiftUI

enum FileNamingFormat: String, CaseIterable, Identifiable {
    case iso8601Compact = "yyyyMMddHHmm"
    case iso8601Readable = "yyyy-MM-dd HH:mm"
    case dateOnly = "yyyy-MM-dd"
    case timestamp = "timestamp"
    case descriptive = "Memory - yyyy-MM-dd HH:mm"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .iso8601Compact:
            return "ISO 8601 Compact (202510131430)"
        case .iso8601Readable:
            return "ISO 8601 Readable (2025-10-13 14:30)"
        case .dateOnly:
            return "Date Only (2025-10-13)"
        case .timestamp:
            return "Unix Timestamp (1728835800)"
        case .descriptive:
            return "Descriptive (Memory - 2025-10-13 14:30)"
        }
    }

    var example: String {
        let date = Date()
        let formatter = DateFormatter()

        switch self {
        case .iso8601Compact:
            formatter.dateFormat = "yyyyMMddHHmm"
            return "\(formatter.string(from: date)).md"
        case .iso8601Readable:
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return "\(formatter.string(from: date)).md"
        case .dateOnly:
            formatter.dateFormat = "yyyy-MM-dd"
            return "\(formatter.string(from: date)).md"
        case .timestamp:
            let timestamp = Int(date.timeIntervalSince1970)
            return "\(timestamp).md"
        case .descriptive:
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return "Memory - \(formatter.string(from: date)).md"
        }
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var fileNamingFormat: FileNamingFormat {
        didSet {
            UserDefaults.standard.set(fileNamingFormat.rawValue, forKey: "fileNamingFormat")
        }
    }

    @Published var defaultTags: [String] {
        didSet {
            UserDefaults.standard.set(defaultTags, forKey: "defaultTags")
        }
    }

    @Published var manualEntryTags: [String] {
        didSet {
            UserDefaults.standard.set(manualEntryTags, forKey: "manualEntryTags")
        }
    }

    @Published var defaultExportFolderBookmark: Data? {
        didSet {
            if let bookmark = defaultExportFolderBookmark {
                UserDefaults.standard.set(bookmark, forKey: "defaultExportFolderBookmark")
            } else {
                UserDefaults.standard.removeObject(forKey: "defaultExportFolderBookmark")
            }
        }
    }

    @Published var defaultExportFolderName: String? {
        didSet {
            if let name = defaultExportFolderName {
                UserDefaults.standard.set(name, forKey: "defaultExportFolderName")
            } else {
                UserDefaults.standard.removeObject(forKey: "defaultExportFolderName")
            }
        }
    }

    init() {
        if let savedFormat = UserDefaults.standard.string(forKey: "fileNamingFormat"),
           let format = FileNamingFormat(rawValue: savedFormat) {
            self.fileNamingFormat = format
        } else {
            self.fileNamingFormat = .iso8601Compact
        }

        if let savedDefaultTags = UserDefaults.standard.array(forKey: "defaultTags") as? [String] {
            self.defaultTags = savedDefaultTags
        } else {
            self.defaultTags = ["memories"]
        }

        if let savedManualTags = UserDefaults.standard.array(forKey: "manualEntryTags") as? [String] {
            self.manualEntryTags = savedManualTags
        } else {
            self.manualEntryTags = ["memories", "manual"]
        }

        self.defaultExportFolderBookmark = UserDefaults.standard.data(forKey: "defaultExportFolderBookmark")
        self.defaultExportFolderName = UserDefaults.standard.string(forKey: "defaultExportFolderName")
    }

    func resolveDefaultExportFolder() -> URL? {
        guard let bookmark = defaultExportFolderBookmark else { return nil }

        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
            if isStale {
                // Bookmark is stale, clear it
                defaultExportFolderBookmark = nil
                defaultExportFolderName = nil
                return nil
            }
            return url
        } catch {
            print("Error resolving bookmark: \(error)")
            defaultExportFolderBookmark = nil
            defaultExportFolderName = nil
            return nil
        }
    }

    func generateFilename(for date: Date) -> String {
        let formatter = DateFormatter()

        switch fileNamingFormat {
        case .iso8601Compact:
            formatter.dateFormat = "yyyyMMddHHmm"
            return "\(formatter.string(from: date)).md"
        case .iso8601Readable:
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return "\(formatter.string(from: date)).md"
        case .dateOnly:
            formatter.dateFormat = "yyyy-MM-dd"
            return "\(formatter.string(from: date)).md"
        case .timestamp:
            let timestamp = Int(date.timeIntervalSince1970)
            return "\(timestamp).md"
        case .descriptive:
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return "Memory - \(formatter.string(from: date)).md"
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings = AppSettings.shared
    @State private var newDefaultTag = ""
    @State private var newManualTag = ""
    @State private var showFolderPicker = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("File Naming")) {
                    Picker("Format", selection: $settings.fileNamingFormat) {
                        ForEach(FileNamingFormat.allCases) { format in
                            VStack(alignment: .leading) {
                                Text(format.displayName)
                                Text(format.example)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(format)
                        }
                    }
                    .pickerStyle(.inline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(settings.fileNamingFormat.example)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    Text("The filename format will be used when exporting journal entries and manual entries.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Default Export Location")) {
                    if let folderName = settings.defaultExportFolderName {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Current Folder")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(folderName)
                                    .font(.body)
                            }
                            Spacer()
                            Button(action: {
                                settings.defaultExportFolderBookmark = nil
                                settings.defaultExportFolderName = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Button(action: {
                        showFolderPicker = true
                    }) {
                        HStack {
                            Image(systemName: "folder")
                            Text(settings.defaultExportFolderName == nil ? "Choose Default Folder" : "Change Folder")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                }

                Section {
                    Text("If set, files will be saved directly to this folder without showing the file picker.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Default Tags (Journal Suggestions)")) {
                    ForEach(settings.defaultTags, id: \.self) { tag in
                        HStack {
                            Text(tag)
                            Spacer()
                            Button(action: {
                                settings.defaultTags.removeAll { $0 == tag }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    HStack {
                        TextField("Add new tag", text: $newDefaultTag)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button(action: {
                            let trimmed = newDefaultTag.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty && !settings.defaultTags.contains(trimmed) {
                                settings.defaultTags.append(trimmed)
                                newDefaultTag = ""
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                        .disabled(newDefaultTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section(header: Text("Manual Entry Tags")) {
                    ForEach(settings.manualEntryTags, id: \.self) { tag in
                        HStack {
                            Text(tag)
                            Spacer()
                            Button(action: {
                                settings.manualEntryTags.removeAll { $0 == tag }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    HStack {
                        TextField("Add new tag", text: $newManualTag)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button(action: {
                            let trimmed = newManualTag.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty && !settings.manualEntryTags.contains(trimmed) {
                                settings.manualEntryTags.append(trimmed)
                                newManualTag = ""
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                        .disabled(newManualTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section {
                    Text("Tags will be included in the YAML frontmatter of exported markdown files. System tags like 'location', 'photo', etc. will be added automatically based on content.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showFolderPicker) {
                FolderPickerView(settings: settings)
            }
        }
    }
}

struct FolderPickerView: UIViewControllerRepresentable {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(settings: settings, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let settings: AppSettings
        let dismiss: DismissAction

        init(settings: AppSettings, dismiss: DismissAction) {
            self.settings = settings
            self.dismiss = dismiss
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            // Start accessing a security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security-scoped resource")
                return
            }

            defer { url.stopAccessingSecurityScopedResource() }

            do {
                // Create a security-scoped bookmark
                let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                settings.defaultExportFolderBookmark = bookmark
                settings.defaultExportFolderName = url.lastPathComponent
                print("Saved bookmark for folder: \(url.lastPathComponent)")
            } catch {
                print("Failed to create bookmark: \(error)")
            }

            dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            dismiss()
        }
    }
}

#Preview {
    SettingsView()
}
