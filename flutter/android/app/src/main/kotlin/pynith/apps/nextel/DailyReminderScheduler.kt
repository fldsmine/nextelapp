package pynith.apps.nextel

import android.Manifest
import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.content.ContextCompat
import java.util.Calendar
import java.util.TimeZone

/** Android-owned exact reminder alarms; Flutter only controls the preference. */
internal object DailyReminderScheduler {
    private const val PREFS_NAME = "app_prefs"
    private const val ENABLED_KEY = "daily_reminder"
    private const val NOTIFICATIONS_KEY = "notifications_enabled"
    private const val SOUND_KEY = "sound"
    private const val VIBRATION_KEY = "vibration"
    private const val CHANNEL_PREFIX = "nextel_daily"
    private const val LAGOS_ZONE = "Africa/Lagos"

    private data class Reminder(
        val id: Int,
        val hour: Int,
        val minute: Int,
        val title: String,
        val body: String,
    )

    private val reminders = listOf(
        Reminder(1, 8, 0, "Morning reminder", "Start your day with smart trading!"),
        Reminder(2, 15, 0, "Afternoon check", "Markets are moving — stay updated."),
        Reminder(3, 19, 7, "Evening wrap", "Review today's trades and plan ahead."),
    )

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(ENABLED_KEY, false)

    fun scheduleAll(context: Context): Boolean {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !alarmManager.canScheduleExactAlarms()
        ) {
            return false
        }
        val allScheduled = reminders.all { schedule(context, alarmManager, it) }
        if (!allScheduled) cancelAll(context)
        return allScheduled
    }

    fun cancelAll(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        reminders.forEach { reminder ->
            alarmManager.cancel(pendingIntent(context, reminder))
            context.getSystemService(NotificationManager::class.java)?.cancel(reminder.id)
        }
    }

    fun onReminderFired(context: Context, id: Int) {
        val reminder = reminders.firstOrNull { it.id == id } ?: return
        if (!isEnabled(context)) return

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        schedule(context, alarmManager, reminder)

        val preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!preferences.getBoolean(NOTIFICATIONS_KEY, true) ||
            !hasNotificationPermission(context)
        ) {
            return
        }
        showNotification(context, reminder, preferences.getBoolean(SOUND_KEY, true),
            preferences.getBoolean(VIBRATION_KEY, false))
    }

    fun restoreAfterBoot(context: Context) {
        if (isEnabled(context)) scheduleAll(context)
    }

    private fun schedule(
        context: Context,
        alarmManager: AlarmManager,
        reminder: Reminder,
    ): Boolean {
        val timeZone = TimeZone.getTimeZone(LAGOS_ZONE)
        val now = Calendar.getInstance(timeZone)
        val target = Calendar.getInstance(timeZone).apply {
            set(Calendar.HOUR_OF_DAY, reminder.hour)
            set(Calendar.MINUTE, reminder.minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (!target.after(now)) target.add(Calendar.DAY_OF_YEAR, 1)

        return runCatching {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                target.timeInMillis,
                pendingIntent(context, reminder),
            )
            true
        }.getOrDefault(false)
    }

    private fun pendingIntent(context: Context, reminder: Reminder): PendingIntent {
        val intent = Intent(context, DailyReminderReceiver::class.java).apply {
            action = "pynith.apps.nextel.DAILY_REMINDER.${reminder.id}"
            putExtra("reminder_id", reminder.id)
        }
        return PendingIntent.getBroadcast(
            context,
            reminder.id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun showNotification(
        context: Context,
        reminder: Reminder,
        soundEnabled: Boolean,
        vibrationEnabled: Boolean,
    ) {
        val channelId = "$CHANNEL_PREFIX-${if (soundEnabled) "sound" else "silent"}-" +
            if (vibrationEnabled) "vibrate" else "quiet"
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationChannel = NotificationChannel(
                channelId,
                "Daily reminders",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Scheduled Nextel daily reminders"
                val attributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .build()
                setSound(
                    if (soundEnabled) {
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    } else {
                        null
                    },
                    if (soundEnabled) attributes else null,
                )
                enableVibration(vibrationEnabled)
            }
            manager.createNotificationChannel(notificationChannel)
        }

        val openApp = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            reminder.id + 10,
            openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            Notification.Builder(context).apply {
                setPriority(Notification.PRIORITY_DEFAULT)
                if (soundEnabled) {
                    setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))
                }
                if (vibrationEnabled) setVibrate(longArrayOf(0, 250, 150, 250))
            }
        }
        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(reminder.title)
            .setContentText(reminder.body)
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .build()
        runCatching { manager.notify(reminder.id, notification) }
    }

    private fun hasNotificationPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
}

class DailyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        DailyReminderScheduler.onReminderFired(
            context,
            intent.getIntExtra("reminder_id", -1),
        )
    }
}

class DailyReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            DailyReminderScheduler.restoreAfterBoot(context)
        }
    }
}
