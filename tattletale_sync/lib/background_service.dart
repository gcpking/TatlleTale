import 'dart:async';
import 'dart:ui';
import 'package:app_usage/app_usage.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_rest.dart';

const _hiddenPackages = {
  'com.android.systemui',
  'com.google.android.gms',
  'com.google.android.gms.supervision',
  'com.motorola.launcher3',
  'com.android.launcher3',
  'com.google.android.apps.nexuslauncher',
  'com.glance.lockscreenM',
  'com.motorola.ccc.ota',
  'com.android.vending',
  'com.google.android.gsf',
  'com.google.android.inputmethod.latin',
  'com.tattletale.sync',
};

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  DateTime lastSync = DateTime.fromMillisecondsSinceEpoch(0).toUtc();
  DateTime lastKnownRefreshRequest =
      DateTime.fromMillisecondsSinceEpoch(0).toUtc();

  // Sync immediately when service starts
  await _doSync();
  lastSync = DateTime.now().toUtc();

  // Every 30 s: check for on-demand refresh, and sync every 15 min anyway
  Timer.periodic(const Duration(seconds: 30), (_) async {
    final prefs = await SharedPreferences.getInstance();
    final familyId = prefs.getString('family_id') ?? '';
    if (familyId.isEmpty) return;

    final now = DateTime.now().toUtc();

    try {
      final reqTime = await FirebaseRest.getRefreshRequestTime(familyId);
      if (reqTime != null &&
          reqTime.isAfter(lastKnownRefreshRequest) &&
          reqTime.isAfter(lastSync)) {
        lastKnownRefreshRequest = reqTime;
        await _doSync();
        lastSync = DateTime.now().toUtc();
        return;
      }
    } catch (_) {}

    if (now.difference(lastSync).inMinutes >= 15) {
      await _doSync();
      lastSync = DateTime.now().toUtc();
    }
  });
}

Future<void> _doSync() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final familyId = prefs.getString('family_id') ?? '';
    if (familyId.isEmpty) return;

    final end = DateTime.now();
    final start = DateTime(end.year, end.month, end.day); // midnight today
    final usageList = await AppUsage().getAppUsage(start, end);

    final usage = usageList
        .where((u) =>
            u.usage.inMinutes > 0 &&
            !_hiddenPackages.contains(u.packageName))
        .map((u) => {
              'packageName': u.packageName,
              'appName': u.appName,
              'usageMinutes': u.usage.inMinutes,
            })
        .toList();

    final ok = await FirebaseRest.pushUsage(familyId, usage);
    if (ok) {
      await prefs.setString('last_sync', DateTime.now().toIso8601String());
    }
  } catch (_) {}
}

Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      isForegroundMode: true,
      notificationChannelId: 'tattletale_sync',
      initialNotificationTitle: 'Tattletale',
      initialNotificationContent: 'Monitoring screen time',
      foregroundServiceNotificationId: 1001,
      autoStart: true,
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
  await service.startService();
}
