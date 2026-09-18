package com.example.prayer_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters

/**
 * بعد إعادة تشغيل الهاتف تُمحى التنبيهات المبرمجة (AlarmManager)،
 * لذلك نطلب من WorkManager تشغيل مهمة Dart تعيد جدولة إشعارات الشهر.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            WorkManager.getInstance(context).enqueueUniqueWork(
                "reschedule_after_boot",
                ExistingWorkPolicy.REPLACE,
                OneTimeWorkRequest.Builder(DummyWorker::class.java).build()
            )
        }
    }
}

class DummyWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result = Result.success()
}
