//
//  JournalingSuggestionsManager.swift
//  Memories for Obsidian
//
//  Created by Craig Eley on 10/13/25.
//

import Foundation
import SwiftUI
import WeatherKit
import CoreLocation
import HealthKit
#if !targetEnvironment(simulator)
@preconcurrency import JournalingSuggestions
#endif

struct WeatherInfo {
    let temperature: Int
    let condition: String
    let symbolName: String
}

@MainActor
class JournalingSuggestionsManager: ObservableObject {
    @Published var selectedSuggestion: JournalingSuggestion?
    @Published var showPicker = false
    @Published var errorMessage: String?

    private let weatherService = WeatherService.shared

    func handleSuggestionSelection(_ suggestion: JournalingSuggestion) {
        selectedSuggestion = suggestion
    }

    func getWeatherForLocation(_ location: CLLocation, date: Date) async -> WeatherInfo? {
        do {
            let calendar = Calendar.current

            // Create a time range: 1 hour before to 1 hour after the memory date
            guard let startDate = calendar.date(byAdding: .hour, value: -1, to: date),
                  let endDate = calendar.date(byAdding: .hour, value: 1, to: date) else {
                print("Failed to create date range for weather")
                return nil
            }

            print("WeatherKit: Fetching weather for date range: \(startDate) to \(endDate)")

            let weather = try await weatherService.weather(for: location, including: .daily(startDate: startDate, endDate: endDate))

            if let dayWeather = weather.first {
                let temp = dayWeather.highTemperature
                let condition = dayWeather.condition.description
                let symbolName = dayWeather.symbolName

                // Convert temperature to Fahrenheit and get just the integer value
                let tempInFahrenheit = temp.converted(to: .fahrenheit).value
                let tempInt = Int(tempInFahrenheit.rounded())

                return WeatherInfo(
                    temperature: tempInt,
                    condition: condition,
                    symbolName: symbolName
                )
            } else {
                print("WeatherKit: No weather data returned")
            }
        } catch let error as NSError {
            // Silently handle WeatherKit authentication errors
            // This allows the app to work without WeatherKit properly configured
            if error.domain == "WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors" {
                print("WeatherKit not configured - skipping weather data")
            } else {
                print("Error fetching weather: \(error)")
            }
        } catch {
            print("Error fetching weather: \(error)")
        }
        return nil
    }

    #if !targetEnvironment(simulator)
    func getSuggestionDetails(for suggestion: JournalingSuggestion) async -> (details: String, tags: Set<String>, places: [String], weather: WeatherInfo?) {
        var details = ""
        var tags = Set<String>()
        var places: [String] = []
        var weatherInfo: WeatherInfo?

        // Get the title
        details += "# \(suggestion.title)\n\n"

        // Get the date
        if let date = suggestion.date {
            details += "Date: \(date.start.formatted(date: .long, time: .shortened))"
            if date.start != date.end {
                details += " - \(date.end.formatted(date: .long, time: .shortened))"
            }
            details += "\n\n"
        }

        // Get content from items
        for item in suggestion.items {
            // Try to get location content
            if item.hasContent(ofType: JournalingSuggestion.Location.self) {
                if let location = try? await item.content(forType: JournalingSuggestion.Location.self) {
                    if let place = location.place {
                        details += "📍 \(place)\n"
                        tags.insert("location")
                        places.append(place)

                        // Fetch weather if we have location and date
                        if weatherInfo == nil, let coordinate = location.location, let memoryDate = suggestion.date?.start {
                            let clLocation = CLLocation(latitude: coordinate.coordinate.latitude, longitude: coordinate.coordinate.longitude)
                            weatherInfo = await getWeatherForLocation(clLocation, date: memoryDate)

                            if let weather = weatherInfo {
                                details += "🌤️ \(weather.condition), \(weather.temperature)°F\n"
                            }
                        }
                    }
                }
            }

            // Try to get reflection content
            if item.hasContent(ofType: JournalingSuggestion.Reflection.self) {
                if let reflection = try? await item.content(forType: JournalingSuggestion.Reflection.self) {
                    details += "💭 \(reflection.prompt)\n"
                    tags.insert("reflection")
                }
            }

            // Try to get workout content
            if item.hasContent(ofType: JournalingSuggestion.Workout.self) {
                if let workout = try? await item.content(forType: JournalingSuggestion.Workout.self) {
                    details += "💪 Workout"

                    // Try to access workout properties
                    var workoutDetails: [String] = []

                    // Try to get duration
                    if let duration = workout.workout.duration {
                        let minutes = Int(duration / 60)
                        workoutDetails.append("\(minutes) min")
                    }

                    // Try to get calories
                    if let energy = workout.workout.totalEnergyBurned {
                        let calories = Int(energy.doubleValue(for: .kilocalorie()))
                        workoutDetails.append("\(calories) cal")
                    }

                    // Try to get average heart rate
                    if let heartRate = workout.averageHeartRate {
                        let bpm = Int(heartRate.doubleValue(for: .count().unitDivided(by: .minute())))
                        workoutDetails.append("\(bpm) bpm")
                    }

                    if !workoutDetails.isEmpty {
                        details += " (\(workoutDetails.joined(separator: ", ")))"
                    }

                    details += "\n"
                    tags.insert("workout")
                }
            }

            // Try to get contact content
            if item.hasContent(ofType: JournalingSuggestion.Contact.self) {
                if let contact = try? await item.content(forType: JournalingSuggestion.Contact.self) {
                    details += "👤 \(contact.name)\n"
                    tags.insert("contact")
                }
            }

            // Try to get photo content
            if item.hasContent(ofType: JournalingSuggestion.Photo.self) {
                if let photo = try? await item.content(forType: JournalingSuggestion.Photo.self) {
                    details += "📷 Photo"

                    // Try to access photo properties
                    // The Photo type should have an asset property that we can use
                    print("Photo object: \(photo)")
                    print("Photo type: \(type(of: photo))")

                    details += "\n"
                    tags.insert("photo")
                }
            }

            // Try to get song content
            if item.hasContent(ofType: JournalingSuggestion.Song.self) {
                if let song = try? await item.content(forType: JournalingSuggestion.Song.self) {
                    details += "🎵 \(song.song.title)"
                    if let artist = song.song.artist {
                        details += " by \(artist)"
                    }
                    details += "\n"
                    tags.insert("music")
                }
            }

            // Try to get motion activity content
            if item.hasContent(ofType: JournalingSuggestion.MotionActivity.self) {
                if let activity = try? await item.content(forType: JournalingSuggestion.MotionActivity.self) {
                    details += "🏃 \(activity.activityType)"
                    if activity.stepCount > 0 {
                        details += " (\(activity.stepCount) steps)"
                    }
                    details += "\n"
                    tags.insert("activity")
                }
            }

            // Try to get state of mind content
            if item.hasContent(ofType: JournalingSuggestion.StateOfMind.self) {
                if let stateOfMind = try? await item.content(forType: JournalingSuggestion.StateOfMind.self) {
                    details += "🧠 State of Mind"
                    // StateOfMind includes valence and labels
                    details += "\n"
                    tags.insert("mental-health")
                }
            }

            // Try to get podcast content
            if item.hasContent(ofType: JournalingSuggestion.Podcast.self) {
                if let podcast = try? await item.content(forType: JournalingSuggestion.Podcast.self) {
                    details += "🎙️ \(podcast.episode.title)"
                    if let show = podcast.episode.show {
                        details += " (\(show))"
                    }
                    details += "\n"
                    tags.insert("podcast")
                }
            }
        }

        details += "\n"

        return (details, tags, places, weatherInfo)
    }
    #endif
}
