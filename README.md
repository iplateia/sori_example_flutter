# SORI Flutter Example

Minimal Flutter app that uses `sorisdk_flutter` to listen for SORI audio
recognition events and render recognized campaigns as cards.

## Requirements

- Flutter 3.3.0 or later
- Android API level 24 or later
- iOS 13.0 or later
- SORI `app_id` and `secret_key` from SORI Console

Do not commit real SORI credentials. This example reads them from
`--dart-define` values.

## Setup

```bash
flutter pub get
```

Run the app with your SORI credentials:

```bash
flutter run \
  --dart-define=SORI_APP_ID=your-application-id \
  --dart-define=SORI_SECRET_KEY=your-secret-key
```

For Android, the Flutter plugin merges the required microphone, network,
foreground-service, and notification declarations. `startRecognition()` asks
for microphone permission when needed. If your Android 13+ product flow must
show the foreground-service notification normally, request notification
permission before starting recognition.

For iOS, this project includes `NSMicrophoneUsageDescription`. Background audio
mode is not enabled because this boilerplate keeps the example focused on the
foreground recognition flow.

## Implementation

The main implementation is in `lib/main.dart`.

- Creates `SORIAudioRecognizer` with `SORI_APP_ID` and `SORI_SECRET_KEY`.
- Subscribes to `recognizer.events` before recognition starts.
- Uses the floating mic button to call `startRecognition()` and
  `stopRecognition()`.
- Uses the app bar sync button to call `updateDatabase()`.
- Renders `event.campaign` or campaign payloads as cards with image, title,
  description, marker, and action affordance.
- Calls `handleActionUrl()` when a campaign card with an action URL is tapped.

Reference: <https://docs.soriapi.com/integration/flutter>
