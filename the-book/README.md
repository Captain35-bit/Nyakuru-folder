# The Book

A React Native mobile application that combines note-taking with an integrated dictionary lookup.

## Features

✏️ **Notes**: Create, edit, and delete personal notes with timestamps
📖 **Dictionary**: Look up word definitions from a comprehensive API
💾 **Saved Definitions**: Save dictionary definitions for future reference
🔍 **Search**: Search for words and notes with ease

## Getting Started

### Prerequisites

- Node.js (v14 or higher)
- npm or yarn
- React Native CLI
- Android Studio (for Android) or Xcode (for iOS)

### Installation

1. Install dependencies:
```bash
npm install
```

2. Start the Metro bundler:
```bash
npm start
```

3. In another terminal, run on Android:
```bash
npm run android
```

Or run on iOS:
```bash
npm run ios
```

## Project Structure

```
the-book/
├── src/
│   └── screens/
│       ├── NotesScreen.js        # Note management
│       ├── DictionaryScreen.js   # Dictionary lookup
│       └── SavedDefinitionsScreen.js  # Saved definitions
├── App.js                          # Main app with navigation
├── package.json                    # Dependencies
└── README.md                       # Documentation
```

## Dependencies

- **react-navigation**: Tab navigation between screens
- **axios**: HTTP client for API calls
- **@react-native-async-storage/async-storage**: Local data persistence
- **react-native**: React Native framework

## API Used

The dictionary feature uses the free [DictionaryAPI](https://dictionaryapi.dev/) which provides:
- Word definitions
- Phonetic pronunciations
- Parts of speech
- Examples

## Features Details

### Notes Tab
- Create new notes with title and content
- Edit existing notes
- Delete notes
- Automatic timestamps
- Local storage persistence

### Dictionary Tab
- Search for any English word
- View definitions, examples, and pronunciation
- Save definitions for later reference
- Uses DictionaryAPI for accurate definitions

### Saved Definitions Tab
- View all saved word definitions
- Delete saved definitions
- Quick reference for frequently looked up words

## License

MIT
