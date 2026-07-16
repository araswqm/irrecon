# IRrecon - AI-Powered Flipper IRDB Remote Finder

Find and use IR remote files from the Flipper IRDB effortlessly.

## Features

- **Camera Search** — Take a photo of your remote, AI identifies it and matches against the local IR database
- **Browse Database** — Chained dropdowns: Device Type → Brand → Model
- **Dynamic Remote UI** — Automatically generated on-screen remote control with grouped buttons
- **Multi-Provider AI** — Bring Your Own Key: OpenAI GPT-4o, Anthropic Claude, Google Gemini, Ollama, or Custom API
- **Full Offline Mode** — Browse and use remotes without internet after initial database sync
- **Material Design 3** — Dynamic Color theming, dark/light mode

## Getting Started

### Prerequisites

- Flutter SDK 3.22+
- Android SDK (for APK build)
- An API key from at least one AI provider (for camera search feature)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/irrecon.git
cd irrecon

# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Build APK
flutter build apk --debug
```

### First Launch

1. Go to **Settings** → set up at least one AI provider API key
2. Go to **Settings** → download the IR database (required for browse & matching)
3. Use **Camera Search** or **Browse Database** to find your remote

## Database Source

This app indexes the [Flipper-IRDB](https://github.com/Lucaslhm/Flipper-IRDB) by Lucaslhm.

## Architecture

```
lib/
├── app/              # App shell, routing, theming
├── core/
│   ├── api/          # AI provider implementations (BYOK)
│   ├── utils/        # Fuzzy matcher, image optimizer, IR parser, layout engine
│   └── constants.dart
├── data/
│   ├── database/     # SQLite via sqflite
│   └── models/       # DeviceType, IRBrand, IRModel, IRKey, AnalysisResult
└── features/
    ├── home/         # Landing screen
    ├── camera/       # Image capture + LLM analysis
    ├── browse/       # Chained dropdown browser
    ├── remote/       # Dynamic remote control UI
    └── settings/     # API keys, DB sync, preferences
```

## License

This project is for educational purposes. IR database content belongs to its respective contributors.
