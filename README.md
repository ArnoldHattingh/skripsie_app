## Friend Radar (skripsie)

Privacy-first, offline-friendly proximity and messaging demo built with Flutter. It uses Bluetooth Low Energy (BLE) to discover and connect to nearby devices, exchanges data securely, and supports joining groups via QR codes.

### Key features
- **BLE scanning and connection**: Powered by `flutter_reactive_ble`
- **Secure transport**: Framing + AEAD encryption via `SecureCodec`
- **QR flows**: Create or join a group using QR codes
- **Compass/location**: Optional signals to help with directionality
- **Cross‑platform**: Android, iOS, macOS, Windows, Linux, and Web (limited BLE on desktop/web)

## What is this project?

Friend Radar is an open-source demo app that enables secure, local proximity-based device discovery and messaging without relying on cloud servers or external infrastructure. It demonstrates how to set up and use BLE for peer-to-peer communication, with a focus on privacy and cross-platform compatibility.

## Project structure
- `lib/services/`
  - `bluetooth_service.dart`: BLE scan/connect, characteristics, encrypted send/receive
  - `secure_codec.dart`: Chunking, AEAD encryption/decryption, reassembly
  - `two_bpp_capture.dart`: 2bpp image capture utilities
- `lib/providers/`: Simple `provider` stores for Bluetooth and location state
- `lib/models/`: Transport and app models (`group_connection_info`, `friend`, `chat_message`)
- `lib/screens/`
  - `join_or_create_group_screen.dart`, `determine_group_info_screen.dart`
  - `device_selection_page.dart`, `chat_page.dart`, `find_friend.dart`
- `lib/components/`: UI components like `message_bubble`

## Requirements
- Flutter (stable) with Dart >= 3.8 (see `environment` in `pubspec.yaml`)
- Xcode (for iOS), Android Studio/SDK (for Android)
- CocoaPods (macOS/iOS): `sudo gem install cocoapods`


## Dependencies (high level)
- BLE: `flutter_reactive_ble`, `flutter_blue_plus`
- State: `provider`
- Sensors: `location`, `flutter_compass`
- QR: `qr_code_scanner_plus`, `qr_flutter`
- Crypto: `crypto`, `cryptography`
- Media: `image_picker`


## How it works (high level)
1) **Group setup via QR**
   - Create or join a group on `JoinOrCreateGroupScreen`
   - A short device/group code derives BLE service and characteristic UUIDs in `BluetoothService.generateUuidsFromCode`
   - `GroupConnectionInfo` includes the symmetric key (`kEnc`) used by `SecureCodec`

2) **Scanning and auto‑connect**
   - `BluetoothService.startScan()` looks for devices that match the expected name `StickLite-<code>` and stops to connect when found

3) **Secure messaging**
   - Sending: JSON → `SecureCodec.encryptJson(...)` → one or more frames → GATT write to RX characteristic
   - Receiving: Subscribe to TX characteristic → decrypt/defragment → JSON delivered to UI callbacks

4) **Progress hooks**
   - `onSendProgress` / `onReceiveProgress` surface multi‑frame progress to the UI



