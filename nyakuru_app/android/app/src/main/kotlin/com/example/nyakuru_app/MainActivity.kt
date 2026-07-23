package com.example.nyakuru_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val NOTIF_ACTION = "com.nyakuru.notification.POSTED"
    private val THEFT_ACTION = "com.nyakuru.theft.TRIGGERED"
    private val AUDIO_READY_ACTION = "com.nyakuru.theft.AUDIO_READY"
    private var notifEventSink: EventChannel.EventSink? = null
    private var theftEventSink: EventChannel.EventSink? = null

    private val notifReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null) return
            val pkg = intent.getStringExtra("package") ?: ""
            val title = intent.getStringExtra("title") ?: ""
            val text = intent.getStringExtra("text") ?: ""
            val map: MutableMap<String, String> = HashMap()
            map["package"] = pkg
            map["title"] = title
            map["text"] = text
            runOnUiThread {
                notifEventSink?.success(map)
            }
        }
    }

    private val theftReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null) return
            val action = intent.action
            if (action == THEFT_ACTION) {
                val ts = intent.getLongExtra("ts", 0L)
                val reason = intent.getStringExtra("reason") ?: ""
                val value = intent.getFloatExtra("value", 0f)
                val map: MutableMap<String, Any> = HashMap()
                map["ts"] = ts
                map["reason"] = reason
                map["value"] = value
                runOnUiThread {
                    theftEventSink?.success(map)
                }
            } else if (action == AUDIO_READY_ACTION) {
                val path = intent.getStringExtra("path") ?: ""
                val map: MutableMap<String, String> = HashMap()
                map["audio_path"] = path
                runOnUiThread {
                    theftEventSink?.success(map)
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        EventChannel(flutterEngine?.dartExecutor?.binaryMessenger, "nyakuru/notifications").setStreamHandler(
            object: EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    notifEventSink = events
                    registerReceiver(notifReceiver, IntentFilter(NOTIF_ACTION))
                }

                override fun onCancel(arguments: Any?) {
                    try { unregisterReceiver(notifReceiver) } catch (e: Exception) {}
                    notifEventSink = null
                }
            }
        )

        val theftFilter = IntentFilter()
        theftFilter.addAction(THEFT_ACTION)
        theftFilter.addAction(AUDIO_READY_ACTION)

        EventChannel(flutterEngine?.dartExecutor?.binaryMessenger, "nyakuru/theft").setStreamHandler(
            object: EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    theftEventSink = events
                    registerReceiver(theftReceiver, theftFilter)
                }

                override fun onCancel(arguments: Any?) {
                    try { unregisterReceiver(theftReceiver) } catch (e: Exception) {}
                    theftEventSink = null
                }
            }
        )

        MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger, "nyakuru/background").setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundScan" -> {
                    val intent = Intent(this, BleScanService::class.java)
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopBackgroundScan" -> {
                    val intent = Intent(this, BleScanService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                "startTheftMonitor" -> {
                    val intent = Intent(this, TheftMonitorService::class.java)
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopTheftMonitor" -> {
                    val intent = Intent(this, TheftMonitorService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
