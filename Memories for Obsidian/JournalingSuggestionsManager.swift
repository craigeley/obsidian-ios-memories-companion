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

struct WorkoutData {
    let activityType: String
    let distance: Double?
    let calories: Int?
    let heartRate: Int?
}

struct SongData {
    let title: String?
    let artist: String?
    let album: String?
}

struct PodcastData {
    let episode: String?
    let show: String?
}

struct PhotoData {
    let count: Int
}

struct ContactData {
    let names: [String]
}

struct ReflectionData {
    let prompts: [String]
}

struct StateOfMindData {
    let state: String
}

struct ActivityData {
    let count: Int
}

struct SuggestionDetailsResult {
    let details: String
    let tags: Set<String>
    let places: [String]
    let weather: WeatherInfo?
    let workouts: [WorkoutData]
    let songs: [SongData]
    let podcasts: [PodcastData]
    let photos: PhotoData?
    let contacts: ContactData?
    let reflections: ReflectionData?
    let stateOfMind: StateOfMindData?
    let activity: ActivityData?
}

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .hiking: return "Hiking"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Strength Training"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        case .cardioDance: return "Dancing"
        case .golf: return "Golf"
        case .tennis: return "Tennis"
        case .basketball: return "Basketball"
        case .soccer: return "Soccer"
        case .baseball: return "Baseball"
        case .americanFootball: return "Football"
        case .hockey: return "Hockey"
        case .lacrosse: return "Lacrosse"
        case .volleyball: return "Volleyball"
        case .boxing: return "Boxing"
        case .kickboxing: return "Kickboxing"
        case .martialArts: return "Martial Arts"
        case .pilates: return "Pilates"
        case .coreTraining: return "Core Training"
        case .crossTraining: return "Cross Training"
        case .flexibility: return "Flexibility"
        case .cooldown: return "Cooldown"
        case .wheelchairRunPace: return "Wheelchair Run"
        case .wheelchairWalkPace: return "Wheelchair Walk"
        case .handCycling: return "Hand Cycling"
        case .downhillSkiing: return "Skiing"
        case .snowboarding: return "Snowboarding"
        case .skatingSports: return "Skating"
        case .paddleSports: return "Paddle Sports"
        case .surfingSports: return "Surfing"
        case .swimBikeRun: return "Triathlon"
        case .other: return "Workout"
        case .archery: return "Archery"
        @unknown default: return "Workout"
        }
    }
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
                return nil
            }

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
            }
        } catch let error as NSError {
            // Silently handle WeatherKit authentication errors
            // This allows the app to work without WeatherKit properly configured
            if error.domain != "WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors" {
                print("Error fetching weather: \(error)")
            }
        } catch {
            print("Error fetching weather: \(error)")
        }
        return nil
    }

    #if !targetEnvironment(simulator)
    func getSuggestionDetails(for suggestion: JournalingSuggestion) async -> SuggestionDetailsResult {
        var details = ""
        var tags = Set<String>()
        var places: [String] = []
        var weatherInfo: WeatherInfo?
        var workouts: [WorkoutData] = []
        var songs: [SongData] = []
        var podcasts: [PodcastData] = []
        var photoCount = 0
        var contactNames: [String] = []
        var reflectionPrompts: [String] = []
        var stateOfMindValue: String?
        var activityCount = 0

        // Get the title
        details += "### \(suggestion.title)\n\n"

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
                    reflectionPrompts.append(reflection.prompt)
                }
            }

            // Try to get workout content
            if item.hasContent(ofType: JournalingSuggestion.Workout.self) {
                if let workout = try? await item.content(forType: JournalingSuggestion.Workout.self) {
                    // Get activity type name from details
                    let activityName = workout.details?.activityType.name ?? "Workout"
                    details += "💪 \(activityName)"

                    // Try to access workout details
                    var workoutDetails: [String] = []
                    var distanceMiles: Double? = nil
                    var caloriesValue: Int? = nil
                    var heartRateValue: Int? = nil

                    // Access details through the details property
                    if let distance = workout.details?.distance {
                        let miles = distance.doubleValue(for: .mile())
                        if miles >= 0.1 {
                            distanceMiles = miles
                            workoutDetails.append(String(format: "%.1f mi", miles))
                        }
                    }

                    if let energy = workout.details?.activeEnergyBurned {
                        let calories = Int(energy.doubleValue(for: .kilocalorie()))
                        caloriesValue = calories
                        workoutDetails.append("\(calories) cal")
                    }

                    if let heartRate = workout.details?.averageHeartRate {
                        let bpm = Int(heartRate.doubleValue(for: .count().unitDivided(by: .minute())))
                        heartRateValue = bpm
                        workoutDetails.append("\(bpm) bpm")
                    }

                    // Store workout data
                    workouts.append(WorkoutData(
                        activityType: activityName,
                        distance: distanceMiles,
                        calories: caloriesValue,
                        heartRate: heartRateValue
                    ))

                    if !workoutDetails.isEmpty {
                        details += " (\(workoutDetails.joined(separator: ", ")))"
                    }

                    details += "\n"

                    // Try to get weather from workout route location
                    if weatherInfo == nil, let route = workout.route, !route.isEmpty, let memoryDate = suggestion.date?.start {
                        // Get the first location from the route
                        let firstLocation = route.first!
                        let clLocation = CLLocation(latitude: firstLocation.coordinate.latitude, longitude: firstLocation.coordinate.longitude)
                        weatherInfo = await getWeatherForLocation(clLocation, date: memoryDate)

                        if let weather = weatherInfo {
                            details += "🌤️ \(weather.condition), \(weather.temperature)°F\n"
                        }
                    }

                    tags.insert("workout")
                }
            }

            // Try to get contact content
            if item.hasContent(ofType: JournalingSuggestion.Contact.self) {
                if let contact = try? await item.content(forType: JournalingSuggestion.Contact.self) {
                    details += "👤 \(contact.name)\n"
                    tags.insert("contact")
                    contactNames.append(contact.name)
                }
            }

            // Try to get photo content
            if item.hasContent(ofType: JournalingSuggestion.Photo.self) {
                if let _ = try? await item.content(forType: JournalingSuggestion.Photo.self) {
                    details += "📷 Photo\n"
                    tags.insert("photo")
                    photoCount += 1
                }
            }

            // Try to get song content
            if item.hasContent(ofType: JournalingSuggestion.Song.self) {
                if let songContent = try? await item.content(forType: JournalingSuggestion.Song.self) {
                    details += "🎵 "

                    // Try to get song title
                    if let song = songContent.song {
                        details += song
                    } else {
                        details += "Song"
                    }

                    // Try to get artist
                    if let artist = songContent.artist {
                        details += " by \(artist)"
                    }

                    // Try to get album
                    if let album = songContent.album {
                        details += " (\(album))"
                    }

                    // Store song data
                    songs.append(SongData(
                        title: songContent.song,
                        artist: songContent.artist,
                        album: songContent.album
                    ))

                    details += "\n"
                    tags.insert("music")
                }
            }

            // Try to get motion activity content
            if item.hasContent(ofType: JournalingSuggestion.MotionActivity.self) {
                if let _ = try? await item.content(forType: JournalingSuggestion.MotionActivity.self) {
                    details += "🏃 Activity\n"
                    tags.insert("activity")
                    activityCount += 1
                }
            }

            // Try to get state of mind content
            if item.hasContent(ofType: JournalingSuggestion.StateOfMind.self) {
                if let stateOfMind = try? await item.content(forType: JournalingSuggestion.StateOfMind.self) {
                    let stateString = "\(stateOfMind.state)"
                    details += "🧠 State of Mind: \(stateString)"
                    details += "\n"
                    tags.insert("mental-health")
                    stateOfMindValue = stateString
                }
            }

            // Try to get podcast content
            if item.hasContent(ofType: JournalingSuggestion.Podcast.self) {
                if let podcast = try? await item.content(forType: JournalingSuggestion.Podcast.self) {
                    details += "🎙️ "

                    // Try to get episode title
                    if let episode = podcast.episode {
                        details += episode
                    } else {
                        details += "Podcast"
                    }

                    // Try to get show name
                    if let show = podcast.show {
                        details += " (\(show))"
                    }

                    // Store podcast data
                    podcasts.append(PodcastData(
                        episode: podcast.episode,
                        show: podcast.show
                    ))

                    details += "\n"
                    tags.insert("podcast")
                }
            }
        }

        details += "\n"

        return SuggestionDetailsResult(
            details: details,
            tags: tags,
            places: places,
            weather: weatherInfo,
            workouts: workouts,
            songs: songs,
            podcasts: podcasts,
            photos: photoCount > 0 ? PhotoData(count: photoCount) : nil,
            contacts: !contactNames.isEmpty ? ContactData(names: contactNames) : nil,
            reflections: !reflectionPrompts.isEmpty ? ReflectionData(prompts: reflectionPrompts) : nil,
            stateOfMind: stateOfMindValue != nil ? StateOfMindData(state: stateOfMindValue!) : nil,
            activity: activityCount > 0 ? ActivityData(count: activityCount) : nil
        )
    }
    #endif
}
