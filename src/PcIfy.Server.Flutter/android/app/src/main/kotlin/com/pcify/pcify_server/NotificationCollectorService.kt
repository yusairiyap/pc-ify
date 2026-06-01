package com.pcify.pcify_server

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class NotificationCollectorService : NotificationListenerService() {

    object NotificationStore {
        var isConnected: Boolean = false
        val notifications: MutableList<StatusBarNotification> = mutableListOf()

        fun clearAll() {
            notifications.clear()
        }
    }

    override fun onListenerConnected() {
        NotificationStore.isConnected = true
        // Load existing active notifications
        try {
            val active = activeNotifications ?: return
            NotificationStore.notifications.clear()
            NotificationStore.notifications.addAll(active)
        } catch (_: Exception) {}
    }

    override fun onListenerDisconnected() {
        NotificationStore.isConnected = false
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return
        NotificationStore.notifications.removeAll { it.key == sbn.key }
        NotificationStore.notifications.add(0, sbn)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        sbn ?: return
        NotificationStore.notifications.removeAll { it.key == sbn.key }
    }
}
