# MediaDL Speech for iPhone

MediaDL Speech provides two on-device Shortcuts actions. **Transcribe Audio (Offline)** accepts an audio file and uses Parakeet Ultra. **Transcribe Reel (Offline)** accepts the Reel audio and optional video, then returns a text transcript with timestamped OCR when video analysis succeeds. The Reel action uses Shortcuts’ long-running task support on iOS 27 and runs in the foreground on iOS 26.

## Setup

1. Open `MediaDLSpeech.xcodeproj` in Xcode with the iOS 27 SDK or later. Select a device running iOS 26 or later.
2. For local signing, add `DEVELOPMENT_TEAM = YOUR_TEAM_ID` to `ios/Signing.local.xcconfig`. Xcode loads this ignored file through `Signing.xcconfig`.
3. Install and open the app. Select a model, then tap **Download Model** or **Import Model Folder from Files**. The download needs an internet connection. Import the extracted Core ML model folder for the selected entry. For a fully offline Whisper import, place `config.json`, `tokenizer_config.json`, and `tokenizer.json` from the matching OpenAI model in the Core ML folder. The app downloads any missing tokenizer files during setup.
4. Follow the [Reel shortcut setup](../README.md#optional-offline-speech-and-on-screen-text).

Parakeet Ultra uses FluidAudio 0.18.3 and its int8 model. Multilingual Whisper models use WhisperKit 0.9.0. Select an installed model to use it in the Reel action. Vision performs OCR on the device and uses supported recognition languages.

See the [physical-device release checks](../CONTRIBUTING.md#build-and-verify-the-ios-companion) for the validation required before distribution.
