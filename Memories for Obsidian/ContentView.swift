//
//  ContentView.swift
//  Memories for Obsidian
//
//  Created by Craig Eley on 10/13/25.
//

import SwiftUI
import UniformTypeIdentifiers
#if !targetEnvironment(simulator)
import JournalingSuggestions
#endif

struct MarkdownContent: Identifiable {
    let id = UUID()
    let content: String
    let filename: String
}

struct ContentView: View {
    @StateObject private var suggestionsManager = JournalingSuggestionsManager()
    @State private var markdownToExport: MarkdownContent?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedSuggestion: JournalingSuggestion?
    @State private var userNote: String = ""
    @State private var showNoteInput = false

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

                if showNoteInput {
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
                }

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
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

        // Generate filename from suggestion's date
        let filename: String
        if let date = suggestion.date?.start {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMddHHmm"
            filename = "\(formatter.string(from: date)).md"
        } else {
            // Fallback to current date if no suggestion date available
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMddHHmm"
            filename = "\(formatter.string(from: Date())).md"
        }

        markdownToExport = MarkdownContent(content: markdown, filename: filename)
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let markdownContent: String
    let filename: String
    let onCompletion: (Result<URL, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(markdownContent: markdownContent, onCompletion: onCompletion)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Create a temporary file with the markdown content
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
        let onCompletion: (Result<URL, Error>) -> Void

        init(markdownContent: String, onCompletion: @escaping (Result<URL, Error>) -> Void) {
            self.markdownContent = markdownContent
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

#Preview {
    ContentView()
}
