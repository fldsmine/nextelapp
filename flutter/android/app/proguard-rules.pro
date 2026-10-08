# WorkManager persists workers by class name and creates them reflectively.
-keep class pynith.apps.nextel.UpdateBackgroundWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class pynith.apps.nextel.PendingLogoutWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
