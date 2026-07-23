# Nyakuru Android Theft Monitor Service notes

This service (TheftMonitorService) runs as a foreground service while "armed" and monitors sensors to detect potential theft (pickup, tilting while phone was stationary).

Behavior summary
- Monitors accelerometer and proximity sensors to detect movement patterns consistent with theft.
- When a theft event is detected:
  - Plays a loud alarm (looping) via MediaPlayer in the service
  - Starts a short audio recording (default 10 seconds) and saves it to app files
  - Broadcasts an Intent with action `com.nyakuru.theft.TRIGGERED` including extras: `ts`, `reason`, `audio_path` (if recorded)
  - The app (Flutter) listens for this broadcast via an EventChannel and will create a Security Log entry and show a local notification.
- The alarm will continue until the user silences it via the app (owner verification required) by calling the stop service method or sending a silence broadcast.

Important notes & limitations
- Camera capture is not performed by the service due to background camera restrictions on modern Android versions. If you want photo capture, the app will attempt to open a camera UI (requires user interaction) or you may opt-in to run capture only when the app is in foreground.
- Audio recording uses RECORD_AUDIO permission; the app will request it only when you arm the theft monitor and enable evidence capture.
- The service requires FOREGROUND_SERVICE and WAKE_LOCK permissions. The persistent notification indicates the phone is being monitored.
- Adjust thresholds carefully — too sensitive will cause false alarms.

Files
- android/app/src/main/kotlin/com/example/nyakuru_app/TheftMonitorService.kt: the foreground service implementation
- lib/main.dart: UI for arming/disarming, sensitivity, evidence toggles, and handling theft events
- android/AndroidManifest.xml: required permissions and service declaration

Testing
- Arm the monitor in the app UI, grant requested permissions when prompted, then simulate movement to trigger an alert. The Security Log should record events and an alarm should play.
