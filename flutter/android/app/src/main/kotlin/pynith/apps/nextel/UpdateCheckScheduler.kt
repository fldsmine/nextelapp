package pynith.apps.nextel

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/** Schedules the daily, network-constrained update check for the Flutter app. */
internal object UpdateCheckScheduler {
    private const val DAILY_WORK_NAME = "flutter_daily_app_upgrade_check"

    fun schedule(context: Context) {
        val request = PeriodicWorkRequestBuilder<UpdateBackgroundWorker>(
            24,
            TimeUnit.HOURS,
        )
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build(),
            )
            .build()

        WorkManager.getInstance(context.applicationContext).enqueueUniquePeriodicWork(
            DAILY_WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
    }
}
