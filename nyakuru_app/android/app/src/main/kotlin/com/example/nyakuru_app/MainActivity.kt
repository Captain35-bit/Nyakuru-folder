package com.example.nyakuru_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel

class MainActivity: FlutterActivity() {
    private val NOTIF_ACTION = "com.nyakuru.notification.POSTED"
    private var eventSink: EventChannel.EventSink? = null
    private val receiver = object : BroadcastReceiver() {
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
                eventSink?.success(map)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        EventChannel(flutterEngine?.dartExecutor?.binaryMessenger, "nyakuru/notifications").setStreamHandler(
            object: EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerReceiver(receiver, IntentFilter(NOTIF_ACTION))
                }

                override fun onCancel(arguments: Any?) {
                    try {
                        unregisterReceiver(receiver)
                    } catch (e: Exception) {
                    }
                    eventSink = null
                }
            }
        )
    }
}
