//
//  MarkdownGenerator.swift
//  Memories for Obsidian
//
//  Created by Craig Eley on 10/13/25.
//

import Foundation
#if !targetEnvironment(simulator)
@preconcurrency import JournalingSuggestions
#endif

struct MarkdownGenerator {
    static func generateMarkdown(from suggestions: [JournalingSuggestion], suggestionsManager: JournalingSuggestionsManager, userNote: String = "") async -> String {
        #if !targetEnvironment(simulator)
        print("MarkdownGenerator: Starting generation for \(suggestions.count) suggestions")

        // Get the date from the first suggestion for frontmatter
        let frontmatterDate: Date
        if let firstDate = suggestions.first?.date?.start {
            frontmatterDate = firstDate
        } else {
            frontmatterDate = Date()
        }

        // Create ISO8601 formatter for YAML frontmatter
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateString = iso8601Formatter.string(from: frontmatterDate)

        // Collect all tags, places, and weather from all suggestions
        var allTags = Set<String>()
        // Add default tags from settings
        allTags.formUnion(AppSettings.shared.defaultTags)
        var allPlaces: [String] = []
        var weatherInfo: WeatherInfo?

        var detailsContent = ""
        for (index, suggestion) in suggestions.enumerated() {
            print("MarkdownGenerator: Processing suggestion \(index + 1)")
            let result = await suggestionsManager.getSuggestionDetails(for: suggestion)
            print("MarkdownGenerator: Details length for suggestion \(index + 1): \(result.details.count)")
            detailsContent += result.details
            detailsContent += "---\n\n"
            allTags.formUnion(result.tags)
            allPlaces.append(contentsOf: result.places)

            // Use weather from first suggestion that has it
            if weatherInfo == nil, let weather = result.weather {
                weatherInfo = weather
            }
        }

        // Start with YAML frontmatter
        var markdown = "---\n"
        markdown += "date_created: \(dateString)\n"

        // Add place if locations were found
        if !allPlaces.isEmpty {
            if allPlaces.count == 1 {
                markdown += "place: \"[[\(allPlaces[0])]]\"\n"
            } else {
                markdown += "place:\n"
                for place in allPlaces {
                    markdown += "  - \"[[\(place)]]\"\n"
                }
            }
        }

        // Add weather if available
        if let weather = weatherInfo {
            markdown += "cond: \(weather.condition)\n"
            markdown += "temp: \(weather.temperature)\n"
        }

        markdown += "tags:\n"
        for tag in allTags.sorted() {
            markdown += "  - \(tag)\n"
        }
        markdown += "---\n\n"

        markdown += detailsContent

        // Add user note if provided
        if !userNote.isEmpty {
            markdown += "## Notes\n\n"
            markdown += userNote + "\n\n"
        }

        print("MarkdownGenerator: Final markdown length: \(markdown.count)")
        return markdown
        #else
        var markdown = "# Journal Memories (Simulator Mode)\n\n"
        markdown += "Generated: \(Date().formatted(date: .long, time: .shortened))\n\n"
        markdown += "---\n\n"
        markdown += "Note: Run on a physical device to fetch real journaling suggestions.\n\n"
        return markdown
        #endif
    }

    static func generateManualEntryMarkdown(note: String, date: Date, weather: WeatherInfo?, placeName: String?) async -> String {
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateString = iso8601Formatter.string(from: date)

        // Start with YAML frontmatter
        var markdown = "---\n"
        markdown += "date_created: \(dateString)\n"

        // Add place if available
        if let place = placeName {
            markdown += "place: \"[[\(place)]]\"\n"
        }

        // Add weather if available
        if let weather = weather {
            markdown += "cond: \(weather.condition)\n"
            markdown += "temp: \(weather.temperature)\n"
        }

        // Add tags from settings
        var tags = Set<String>(AppSettings.shared.manualEntryTags)
        if placeName != nil {
            tags.insert("location")
        }

        markdown += "tags:\n"
        for tag in tags.sorted() {
            markdown += "  - \(tag)\n"
        }
        markdown += "---\n\n"

        markdown += "# Manual Entry\n\n"
        markdown += "Date: \(date.formatted(date: .long, time: .shortened))\n"

        // Add place to body if available
        if let place = placeName {
            markdown += "📍 \(place)\n"
        }

        // Add weather to body if available
        if let weather = weather {
            markdown += "🌤️ \(weather.condition), \(weather.temperature)°F\n"
        }

        markdown += "\n---\n\n"

        markdown += note + "\n\n"

        return markdown
    }

    static func saveMarkdownToFile(_ markdown: String, filename: String = "journal_memories.md") -> URL? {
        let fileManager = FileManager.default

        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let fileURL = documentsDirectory.appendingPathComponent(filename)

        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error saving markdown: \(error)")
            return nil
        }
    }
}
