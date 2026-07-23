package com.example.nyakuru_app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.content.Intent

class NyakuruNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val pkg = sbn.packageName ?: return
        val n = sbn.notification
        val extras = n.extras
        val title = extras.getString(android.app.Notification.EXTRA_TITLE) ?: ""
        val text = extras.getCharSequence(android.app.Notification.EXTRA_TEXT)?.toString() ?: ""
        val i = Intent("com.nyakuru.notification.POSTED")
        i.putExtra("package", pkg)
        i.putExtra("title", title)
        i.putExtra("text", text)
        sendBroadcast(i)
    }
}
