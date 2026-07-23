import 'dart:async';
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadPrebundledIfNeeded();
    _loadAlerts();
    _initConnectivity();
    _loadDeviceInfo();
    _startNotificationListener();
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
        final text = m['text'] ?? '';
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
          trailing: Text(a['ts']?.toString()?.split('T')?.first ?? ''),
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
