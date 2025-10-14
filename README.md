# Memories for Obsidian

An iOS app that uses Apple's Journaling Suggestions API to fetch personal memories and export them as Markdown files compatible with Obsidian.

## Features

- Fetches journaling suggestions from the native iOS picker
- Includes various types of memories: photos, locations, workouts, contacts, media, and more
- Exports memories as markdown files
- Easy sharing to Obsidian or other apps via iOS Files app
- Privacy-focused: Only selected memories are shared with the app

## Screenshots
![](https://github.com/craigeley/obsidian-ios-memories-companion/blob/main/screenshots/shot_01.png)

![](https://github.com/craigeley/obsidian-ios-memories-companion/blob/main/screenshots/shot_02.png)

![](https://github.com/craigeley/obsidian-ios-memories-companion/blob/main/screenshots/shot_03.png)

## Requirements

- **iOS 17.2 or later** (Journaling Suggestions API was introduced in iOS 17.2)
- **Physical iPhone device** (The Journaling Suggestions API is NOT available in the iOS Simulator)
- Xcode 16.0 or later for building

## Important Notes

### Simulator Limitation

The Journaling Suggestions API is **only available on physical iOS devices**. When you run this app in the iOS Simulator, you'll see an error message explaining this limitation. To actually use the app and fetch memories, you must:

1. Connect a physical iPhone running iOS 17.2 or later
2. Select your device as the build destination in Xcode
3. Build and run the app on your physical device

### Privacy & Permissions

This app requires the Journaling Suggestions entitlement, which is already configured in the project. When you first run the app and tap "Fetch Memories," iOS will prompt you to grant access to journaling suggestions. This is a privacy-preserving API that only shares the specific memories you interact with.

## How to Use

1. **Build and Install**
   - Open `Memories for Obsidian.xcodeproj` in Xcode
   - Connect your iPhone (iOS 17.2+)
   - Select your device as the build destination
   - Click Run (⌘R) to build and install the app

2. **Fetch Memories**
   - Open the app on your iPhone
   - Tap "Fetch Memories" to retrieve journaling suggestions from the past 7 days
   - The app will show how many memories were found

3. **Export to Markdown**
   - Tap "Export to Markdown" to generate a markdown file
   - The file is saved to the app's documents directory
   - A share sheet will appear, allowing you to:
     - Save to Files app
     - Share to Obsidian (if installed)
     - Share to other apps
     - AirDrop to your Mac

4. **Import to Obsidian**
   - Use the share sheet to save the file to your Obsidian vault
   - Or AirDrop the file to your Mac and manually place it in your vault

## Project Structure

- `ContentView.swift` - Main UI with buttons to fetch and export memories
- `JournalingSuggestionsManager.swift` - Handles fetching journaling suggestions from iOS
- `MarkdownGenerator.swift` - Converts suggestions to markdown format and saves files
- `Memories for Obsidian.entitlements` - Contains the required journaling suggestions entitlement

## Configuration

The app fetches suggestions from the past 7 days and includes:
- Exercise activities
- Location data
- Photos
- Reflections
- Media
- Contacts
- Workouts

You can customize the date range and included types by modifying the `fetchSuggestions()` method in `JournalingSuggestionsManager.swift`.

## Markdown Output Format

The generated markdown file includes:
- A title header
- Generation timestamp
- Individual memory sections with:
  - Memory title
  - Date and time
  - Memory content
  - Separator lines between memories

## Troubleshooting

### "No such module 'JournalingSuggestions'" error
This means you're building for the simulator. Build for a physical device instead.

### No memories found
- Make sure you have activity on your iPhone (photos taken, places visited, workouts, etc.)
- The API looks back 7 days - you need recent activity
- Check that you granted permission when prompted

### Can't find the exported file
- Tap "Export to Markdown" and use the share sheet
- Choose "Save to Files" to pick a location
- Or share directly to Obsidian or another app

## Privacy

This app uses Apple's privacy-preserving Journaling Suggestions API. The API does not give the app access to your raw data (photos, locations, etc.). Instead, it provides curated suggestions, and only the suggestions you explicitly interact with are shared with the app.

## License

This project is provided as-is for educational and personal use.

## Resources

- [Apple Journaling Suggestions Documentation](https://developer.apple.com/documentation/journalingsuggestions)
- [Obsidian](https://obsidian.md)

## Notes

- This app is designed to work with Obsidian but the markdown files can be used with any markdown-compatible note-taking app
- The app saves files to its documents directory and provides a share sheet for easy export
- You can run the export multiple times to get updated memories
