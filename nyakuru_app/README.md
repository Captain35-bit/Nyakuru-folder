# Nyakuru Flutter starter app

This is a minimal, offline-capable Flutter starter app intended as a base for building a device security monitoring application.

What this includes
- A simple UI that shows device info, connectivity and permissions state
- Local alerts stored with Hive (local key-value DB)
- Local notifications via flutter_local_notifications
- BLE scanner, Wi‑Fi scanning guidance (requires Android manifest changes), GPS sharing, and Notification listener to detect messages from other apps
- Package/permission watcher and Usage access UI

How to use
1. Install Flutter SDK: https://flutter.dev/docs/get-started/install
2. From the repository root run:
   cd nyakuru_app
   flutter pub get
3. Run on an attached device or emulator (Android):
   flutter run

Permissions & setup (Android)
- This app requires several runtime permissions: Location (ACCESS_FINE_LOCATION), Bluetooth scan/connect (on Android 12+), and Notification access.
- To enable notification monitoring: open Settings -> Apps -> Special app access -> Notification access -> enable Nyakuru.
- To enable Usage access (foreground app monitoring): Settings -> Security -> Usage Access -> enable Nyakuru.

Notes
- Message bodies are NOT stored by default (Option A). Only metadata is stored unless you opt into storing bodies in the app settings.
- Background monitoring is supported via NotificationListenerService and UsageStats; please grant the required system permissions.
