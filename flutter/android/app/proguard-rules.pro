# WorkManager persists this worker by class name and creates it reflectively.
-keep class pynith.apps.nextel.UpdateBackgroundWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
