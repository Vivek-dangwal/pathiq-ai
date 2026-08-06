import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(HazardDetectionTaskHandler());
}

class HazardDetectionTaskHandler extends TaskHandler {
  int _tickCount = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _tickCount = 0;
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _tickCount++;
    FlutterForegroundTask.updateService(
      notificationTitle: 'PathIQ AI — Monitoring for hazards',
      notificationText: 'Service alive: $_tickCount checks',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Cleanup if needed
  }
}

void initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'pathiq_hazard_detection',
      channelName: 'PathIQ Hazard Detection Service',
      channelDescription: 'Keeps hazard detection running while the app is in the background.',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: false,
    ),
  );
}

Future<bool> startForegroundTask() async {
  final result = await FlutterForegroundTask.startService(
    notificationTitle: 'PathIQ AI — Monitoring for hazards',
    notificationText: 'Starting...',
    callback: startForegroundCallback,
  );
  return result is ServiceRequestSuccess;
}

Future<bool> stopForegroundTask() async {
  final result = await FlutterForegroundTask.stopService();
  return result is ServiceRequestSuccess;
}