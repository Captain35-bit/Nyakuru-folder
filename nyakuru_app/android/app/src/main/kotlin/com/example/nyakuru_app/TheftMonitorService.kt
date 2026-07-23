package com.example.nyakuru_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.concurrent.thread

class TheftMonitorService : Service(), SensorEventListener {
    private val CHANNEL_ID = "NyakuruTheft"
    private lateinit var sensorManager: SensorManager
    private var accelSensor: Sensor? = null
    private var proximitySensor: Sensor? = null
    private var lastAccel = FloatArray(3)
    private var stationary = true
    private var sensitivity = 12.0f // default threshold
    private var alarmPlayer: MediaPlayer? = null
    private var recorder: MediaRecorder? = null
    private var wakelock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notification: Notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Nyakuru — Theft Monitor")
                .setContentText("Monitoring for unauthorized movement (armed)")
                .setSmallIcon(R.mipmap.ic_launcher)
                .build()
        } else {
            Notification.Builder(this)
                .setContentTitle("Nyakuru — Theft Monitor")
                .setContentText("Monitoring for unauthorized movement (armed)")
                .setSmallIcon(R.mipmap.ic_launcher)
                .build()
        }
        startForeground(201, notification)

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        proximitySensor = sensorManager.getDefaultSensor(Sensor.TYPE_PROXIMITY)
        sensorManager.registerListener(this, accelSensor, SensorManager.SENSOR_DELAY_NORMAL)
        proximitySensor?.also { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakelock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Nyakuru:TheftLock")
        wakelock?.acquire(10*60*1000L /*10 minutes*/)
    }

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        stopAlarm()
        stopRecording()
        wakelock?.release()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(CHANNEL_ID, "Nyakuru Theft Monitor", NotificationManager.IMPORTANCE_HIGH)
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type == Sensor.TYPE_ACCELEROMETER) {
            val x = event.values[0]
            val y = event.values[1]
            val z = event.values[2]
            val mag = Math.sqrt((x*x + y*y + z*z).toDouble()).toFloat()
            // Heuristic: if magnitude deviates from gravity significantly and previously stationary -> movement
            val diff = Math.abs(mag - 9.81f)
            if (stationary && diff > sensitivity) {
                stationary = false
                // suspicious movement detected
                onTheftDetected("accel_motion", diff)
            } else if (diff < 0.5f) {
                stationary = true
            }
        }
        // proximity sensor could be used to check if phone is out of pocket; not used in this simple heuristic
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun onTheftDetected(reason: String, value: Float) {
        Log.i("TheftService", "Theft detected: $reason val=$value")
        // start alarm and record audio
        startAlarm()
        startRecordingShort()
        // broadcast event with audio path (when ready later)
        val intent = Intent("com.nyakuru.theft.TRIGGERED")
        intent.putExtra("ts", System.currentTimeMillis())
        intent.putExtra("reason", reason)
        intent.putExtra("value", value)
        sendBroadcast(intent)
    }

    private fun startAlarm() {
        try {
            stopAlarm()
            alarmPlayer = MediaPlayer.create(this, R.raw.alarm)
            alarmPlayer?.isLooping = true
            alarmPlayer?.setVolume(1.0f, 1.0f)
            alarmPlayer?.start()
        } catch (e: Exception) {
            // ignore
        }
    }

    private fun stopAlarm() {
        try {
            alarmPlayer?.stop()
            alarmPlayer?.release()
            alarmPlayer = null
        } catch (e: Exception) {
        }
    }

    private fun startRecordingShort() {
        try {
            stopRecording()
            val dir = filesDir
            val ts = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val file = File(dir, "nyakuru_audio_$ts.m4a")
            recorder = MediaRecorder()
            recorder?.setAudioSource(MediaRecorder.AudioSource.MIC)
            recorder?.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            recorder?.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            recorder?.setOutputFile(file.absolutePath)
            recorder?.prepare()
            recorder?.start()
            // record for 10 seconds in background thread then stop
            thread {
                try {
                    Thread.sleep(10_000)
                } catch (e: InterruptedException) {}
                stopRecording()
                // broadcast with audio path
                val i = Intent("com.nyakuru.theft.AUDIO_READY")
                i.putExtra("path", file.absolutePath)
                sendBroadcast(i)
            }
        } catch (e: Exception) {
            // ignore
        }
    }

    private fun stopRecording() {
        try {
            recorder?.stop()
            recorder?.release()
            recorder = null
        } catch (e: Exception) {
        }
    }
}
