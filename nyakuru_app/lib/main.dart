import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:audioplayers/audioplayers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('nyakuruBox');
  await Hive.openBox('alerts');
  runApp(NyakuruApp());
}

class NyakuruApp extends StatefulWidget {
  @override
  State<NyakuruApp> createState() => _NyakuruAppState();
}

class _NyakuruAppState extends State<NyakuruApp> {
  final alertsBox = Hive.box('alerts');
  final box = Hive.box('nyakuruBox');
  List<dynamic> alerts = [];
  String connectivity = 'Unknown';
  String deviceSummary = '';
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  late StreamSubscription<ConnectivityResult> _connectivitySub;

  static const EventChannel _notificationChannel = EventChannel('nyakuru/notifications');
  static const EventChannel _theftChannel = EventChannel('nyakuru/theft');
  static const MethodChannel _backgroundChannel = MethodChannel('nyakuru/background');

  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  encrypt_pkg.Encrypter? _encrypter;
  encrypt_pkg.Key? _encKey;
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadPrebundledIfNeeded();
    _loadAlerts();
    _initConnectivity();
    _loadDeviceInfo();
    _startNotificationListener();
    _startTheftListener();
    _ensureKey();
  }

  Future<void> _ensureKey() async {
    final existing = await _secureStorage.read(key: 'enc_key');
    if (existing != null) {
      _encKey = encrypt_pkg.Key.fromBase64(existing);
    } else {
      final rnd = Random.secure();
      final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
      final keyB64 = base64Encode(bytes);
      await _secureStorage.write(key: 'enc_key', value: keyB64);
      _encKey = encrypt_pkg.Key.fromBase64(keyB64);
    }
    _encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(_encKey!, mode: encrypt_pkg.AESMode.cbc));
  }

  Future<String> _encryptFile(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final iv = encrypt_pkg.IV.fromSecureRandom(16);
      final encrypted = _encrypter!.encryptBytes(bytes, iv: iv);
      final outPath = '$path.enc';
      final outFile = File(outPath);
      await outFile.writeAsBytes(iv.bytes + encrypted.bytes);
      // delete original file
      try { await file.delete(); } catch (e) {}
      return outPath;
    } catch (e) {
      return '';
    }
  }

  Future<String> _decryptToTemp(String encPath) async {
    try {
      final encFile = File(encPath);
      final all = await encFile.readAsBytes();
      final ivBytes = all.sublist(0, 16);
      final cipher = all.sublist(16);
      final iv = encrypt_pkg.IV(ivBytes);
      final decrypted = _encrypter!.decryptBytes(encrypt_pkg.Encrypted(cipher), iv: iv);
      final tmp = await Directory.systemTemp.createTemp('nyakuru');
      final out = File('${tmp.path}/${encFile.uri.pathSegments.last.replaceAll('.enc', '')}');
      await out.writeAsBytes(decrypted);
      return out.path;
    } catch (e) {
      return '';
    }
  }

  Future<void> _playEncryptedAudio(String encPath) async {
    final tmp = await _decryptToTemp(encPath);
    if (tmp.isNotEmpty) {
      await _player.stop();
      await _player.play(DeviceFileSource(tmp));
    }
  }

  void _startTheftListener() {
    _theftChannel.receiveBroadcastStream().listen((event) async {
      try {
        final Map m = Map.from(event as Map);
        if (m.containsKey('audio_path')) {
          final rawPath = m['audio_path'] as String;
          final enc = await _encryptFile(rawPath);
          final alert = {
            'type': 'theft',
            'reason': m['reason'] ?? 'unknown',
            'ts': DateTime.now().toIso8601String(),
            'audio_enc_path': enc,
          };
          alertsBox.add(alert);
          _loadAlerts();
          _showNotification('Theft alert', 'Movement detected — evidence saved');
        } else if (m.containsKey('ts')) {
          final alert = {
            'type': 'theft',
            'reason': m['reason'] ?? 'unknown',
            'ts': DateTime.fromMillisecondsSinceEpoch((m['ts'] as int)).toIso8601String(),
          };
          alertsBox.add(alert);
          _loadAlerts();
          _showNotification('Theft alert', 'Movement detected');
        }
      } catch (e) {
        // ignore
      }
    });
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _localNotifications.initialize(initializationSettings);
  }

  void _startNotificationListener() {
    _notificationChannel.receiveBroadcastStream().listen((event) {
      // event expected as Map
      try {
        final Map m = Map.from(event as Map);
        final pkg = m['package'] ?? 'unknown';
        final title = m['title'] ?? '';
        final alert = {
          'type': 'notification',
          'package': pkg,
          'title': title,
          'ts': DateTime.now().toIso8601String(),
          // body is NOT stored by default per Option A
        };
        alertsBox.add(alert);
        _loadAlerts();
        _showNotification('New message from $pkg', title ?? '');
      } catch (e) {
        // ignore
      }
    });
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'nyakuru_alerts',
      'Nyakuru Alerts',
      channelDescription: 'Security alerts and notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await _localNotifications.show(0, title, body, platformChannelSpecifics, payload: 'alert');
  }

  Future<void> _loadPrebundledIfNeeded() async {
    final hasLoaded = box.get('prebundled_loaded', defaultValue: false) as bool;
    if (!hasLoaded) {
      try {
        final jsonStr = await rootBundle.loadString('assets/sample_data.json');
        final List<dynamic> items = json.decode(jsonStr) as List<dynamic>;
        for (var it in items) {
          alertsBox.add(it);
        }
      } catch (e) {
        // ignore
      }
      await box.put('prebundled_loaded', true);
      _loadAlerts();
    }
  }

  void _loadAlerts() {
    alerts = alertsBox.values.toList();
    setState(() {});
  }

  void _initConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((c) {
      setState(() {
        connectivity = c.toString();
      });
    });
  }

  Future<void> _loadDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      final info = await deviceInfo.deviceInfo;
      deviceSummary = info.toMap().entries.map((e) => '${e.key}: ${e.value}').take(20).join('\n');
      setState(() {});
    } catch (e) {
      deviceSummary = 'Unable to fetch device info: $e';
      setState(() {});
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    final permissions = [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.storage,
      Permission.notification,
    ];

    final statuses = await Future.wait(permissions.map((p) => p.status));
    final needRequest = <Permission>[];
    for (int i = 0; i < permissions.length; i++) {
      if (!statuses[i].isGranted) needRequest.add(permissions[i]);
    }

    if (needRequest.isNotEmpty) {
      final results = await needRequest.request();
      bool anyDenied = results.values.any((s) => !s.isGranted);
      if (anyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Some permissions were not granted — open Settings to enable full monitoring.')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Permissions already granted')));
    }
  }

  Future<void> _generateSampleAlert() async {
    final alert = {
      'title': 'Suspicious event',
      'message': 'Sample suspicious activity detected at ${DateTime.now()}',
      'ts': DateTime.now().toIso8601String()
    };
    await alertsBox.add(alert);
    _loadAlerts();
    await _showNotification(alert['title'] as String, alert['message'] as String);
  }

  Future<void> _getAndShareLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location services are disabled')));
        return;
      }
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location permission denied forever')));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      final mapUrl = 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
      final smsUri = Uri.parse('sms:?body=My location: $mapUrl');
      if (await canLaunchUrl(smsUri)) await launchUrl(smsUri);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to get location: $e')));
    }
  }

  Future<List<Application>> _listInstalledApps() async {
    return await DeviceApps.getInstalledApplications(includeSystemApps: false, onlyAppsWithLaunchIntent: true);
  }

  void _startBleScan() {
    FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
    flutterBlue.startScan(timeout: Duration(seconds: 8));
    flutterBlue.scanResults.listen((results) {
      for (var r in results) {
        final alert = {
          'type': 'ble',
          'name': r.device.name ?? r.device.id.id,
          'id': r.device.id.id,
          'rssi': r.rssi,
          'ts': DateTime.now().toIso8601String(),
        };
        alertsBox.add(alert);
      }
      _loadAlerts();
    });
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    _player.dispose();
    super.dispose();
  }

  Widget _buildSecurityLog() {
    final reversed = alerts.reversed.toList();
    return ListView.builder(
      itemCount: reversed.length,
      itemBuilder: (_, i) {
        final a = Map<String, dynamic>.from(reversed[i]);
        return ListTile(
          title: Text(a['title'] ?? a['name'] ?? a['type'] ?? 'Event'),
          subtitle: Text(a['message'] ?? '${a['package'] ?? ''} ${a['rssi'] != null ? 'RSSI:${a['rssi']}' : ''}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (a['audio_enc_path'] != null) IconButton(icon: Icon(Icons.play_arrow), onPressed: () async { await _playEncryptedAudio(a['audio_enc_path']); }),
            Text(a['ts']?.toString()?.split('T')?.first ?? ''),
          ],),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nyakuru — Security Monitor',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Nyakuru — Security Monitor'),
          actions: [Padding(padding: EdgeInsets.all(12), child: Center(child: Text(connectivity)))],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Device info:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Expanded(
                flex: 0,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                  child: SingleChildScrollView(
                    child: Text(deviceSummary, maxLines: 8, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton(onPressed: _checkAndRequestPermissions, child: Text('Check Permissions')),
                  SizedBox(width: 12),
                  ElevatedButton(onPressed: _generateSampleAlert, child: Text('Generate Alert')),
                  SizedBox(width: 12),
                  ElevatedButton(onPressed: _startBleScan, child: Text('Scan BLE')),
                ],
              ),
              SizedBox(height: 12),
              Row(children: [ElevatedButton(onPressed: _getAndShareLocation, child: Text('Share my GPS'))]),
              SizedBox(height: 12),
              Text('Security Log:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Expanded(child: _buildSecurityLog()),
            ],
          ),
        ),
      ),
    );
  }
}
