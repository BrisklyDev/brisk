import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:brisk/util/app_logger.dart';

class NotificationManager {
  static final FlutterLocalNotificationsPlugin flnPlugin =
      FlutterLocalNotificationsPlugin();
  static const downloadCompletionHeader = "Download Complete";
  static const downloadFailureHeader = "Download Failed!";
  static late bool _initialized;

  static void init() async {
    const LinuxInitializationSettings linuxInitSettings =
        LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );
    const DarwinInitializationSettings darwinInitSettings =
        DarwinInitializationSettings();
    const WindowsInitializationSettings windowsInitSettings =
        WindowsInitializationSettings(
      appName: 'Brisk',
      appUserModelId: 'aminbhst.brisk',
      guid: '0e55ea0a-de5b-4d9a-97d8-3349aef0d9ca',
    );
    try {
      await flnPlugin.initialize(
        const InitializationSettings(
          linux: linuxInitSettings,
          macOS: darwinInitSettings,
          windows: windowsInitSettings,
        ),
      );
      _initialized = true;
    } catch (e) {
      Logger.log("Failed to initialize notification plugin!");
      Logger.log(e);
      _initialized = false;
    }
  }

  static void showNotification(String header, String body) async {
    if (!_initialized) return;
    final id = Random().nextInt(100);
    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();
    const WindowsNotificationDetails windowsDetails =
        WindowsNotificationDetails();
    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails();
    const NotificationDetails notificationDetails = NotificationDetails(
        linux: linuxDetails, macOS: darwinDetails, windows: windowsDetails);
    await flnPlugin.show(
      id,
      header,
      body,
      notificationDetails,
    );
  }
}
