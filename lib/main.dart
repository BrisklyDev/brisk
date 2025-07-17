import 'dart:async';
import 'dart:io';
import 'package:brisk/db/migration_manager.dart';
import 'package:brisk/provider/ffmpeg_installation_provider.dart';
import 'package:brisk/provider/locale_provider.dart';
import 'package:brisk/provider/search_bar_notifier_provider.dart';
import 'package:brisk/util/app_logger.dart';
import 'package:brisk/util/auto_updater_util.dart';
import 'package:brisk/browser_extension/browser_extension_server.dart';
import 'package:brisk/constants/app_closure_behaviour.dart';
import 'package:brisk/db/hive_util.dart';
import 'package:brisk/provider/download_request_provider.dart';
import 'package:brisk/provider/pluto_grid_check_row_provider.dart';
import 'package:brisk/provider/queue_provider.dart';
import 'package:brisk/provider/settings_provider.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/theme/application_theme_holder.dart';
import 'package:brisk/util/database_migration.dart';
import 'package:brisk/util/download_addition_ui_util.dart';
import 'package:brisk/util/github_star_handler.dart';
import 'package:brisk/util/hot_key_util.dart';
import 'package:brisk/util/launch_at_startup_util.dart';
import 'package:brisk/util/notification_manager.dart';
import 'package:brisk/util/single_instance_handler.dart';
import 'package:brisk/util/tray_handler.dart';
import 'package:brisk/widget/base/app_exit_dialog.dart';
import 'package:brisk/widget/base/global_context.dart';
import 'package:brisk/widget/download/download_grid.dart';
import 'package:brisk/widget/loader/file_info_loader.dart';
import 'package:brisk/widget/queue/download_queue_list.dart';
import 'package:brisk/widget/side_menu/side_menu.dart';
import 'package:brisk/widget/top_menu/download_queue_top_menu.dart';
import 'package:brisk/widget/top_menu/queue_top_menu.dart';
import 'package:brisk/widget/top_menu/top_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'l10n/app_localizations.dart';
import 'util/file_util.dart';
import 'setting/settings_cache.dart';

// TODO Fix resizing the window when a row is selected
Future<void> main(List<String> args) async {
  if (!Platform.isWindows) {
    await SingleInstanceHandler.tryConnectSocket();
  }
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SingleInstanceHandler.init();
    await Logger.init();
    await migrateDatabaseLocation();
    await windowManager.ensureInitialized();
    tz.initializeTimeZones();
    await HiveUtil.instance.initHive();
    await setupLaunchAtStartup();
    await FileUtil.setDefaultTempDir();
    await FileUtil.setDefaultSaveDir();
    await HiveUtil.instance.putInitialBoxValues();
    await MigrationManager.runMigrations();
    await SettingsCache.setCachedSettings();
    await updateLaunchAtStartupSetting();
    LocaleProvider.instance.setCurrentLocale();
    ApplicationThemeHolder.setActiveTheme();
    launchedAtStartup = args.contains(fromStartupArg);

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider.instance,
          ),
          ChangeNotifierProvider<QueueProvider>(
            create: (_) => QueueProvider(),
          ),
          ChangeNotifierProvider<ThemeProvider>(
            create: (_) => ThemeProvider(),
          ),
          ChangeNotifierProvider<PlutoGridCheckRowProvider>(
            create: (_) => PlutoGridCheckRowProvider(),
          ),
          ChangeNotifierProvider<LocaleProvider>(
            create: (_) => LocaleProvider.instance,
          ),
          ChangeNotifierProvider<FFmpegInstallationProvider>(
            create: (_) => FFmpegInstallationProvider(),
          ),
          ChangeNotifierProvider<SearchBarNotifierProvider>(
            create: (_) => SearchBarNotifierProvider(),
          ),
          ChangeNotifierProxyProvider<PlutoGridCheckRowProvider,
              DownloadRequestProvider>(
            create: (_) => DownloadRequestProvider(PlutoGridCheckRowProvider()),
            update: (context, plutoProvider, downloadProvider) {
              if (downloadProvider == null) {
                return DownloadRequestProvider(plutoProvider);
              } else {
                downloadProvider.plutoProvider = plutoProvider;
                return downloadProvider;
              }
            },
          ),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    print('Unhandled error: $error');
    print(stack);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: Provider.of<LocaleProvider>(context).locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocaleProvider.locales.keys.map(
        (locale) => Locale(locale),
      ),
      navigatorKey: globalContext,
      debugShowCheckedModeBanner: false,
      title: 'Brisk',
      theme: ThemeData(
        fontFamily: Platform.isWindows ? 'Segoe UI' : "Inter",
        useMaterial3: false,
        dialogTheme: DialogThemeData(backgroundColor: Colors.transparent),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with WindowListener, TrayListener {
  final FocusNode _globalFocusNode = FocusNode();

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (!mounted || !isPreventClose) return;
    switch (SettingsCache.appClosureBehaviour) {
      case AppClosureBehaviour.ask:
        showAppClosureDialog();
        break;
      case AppClosureBehaviour.minimizeToTray:
        TrayHandler.setTray(context);
        windowManager.hide();
        if (Platform.isMacOS) {
          windowManager.setSkipTaskbar(true);
        }
        break;
      case AppClosureBehaviour.exit:
        windowManager.destroy().then((_) => exit(0));
        break;
    }
  }

  void showAppClosureDialog() {
    showDialog(
      context: context,
      builder: (_) => AppExitDialog(
        onExitPressed: (rememberChecked) async {
          Navigator.of(context).pop();
          if (rememberChecked) {
            await saveNewAppClosureBehaviour(AppClosureBehaviour.exit);
          }
          windowManager.destroy().then((_) => exit(0));
        },
        onMinimizeToTrayPressed: (rememberChecked) {
          if (rememberChecked) {
            saveNewAppClosureBehaviour(AppClosureBehaviour.minimizeToTray);
          }
          TrayHandler.setTray(context);
          windowManager.hide();
          if (Platform.isMacOS) {
            windowManager.setSkipTaskbar(true);
          }
        },
      ),
    );
  }

  Future<void> saveNewAppClosureBehaviour(AppClosureBehaviour behaviour) async {
    SettingsCache.appClosureBehaviour = behaviour;
    await SettingsCache.saveCachedSettingsToDB();
  }

  @override
  void initState() {
    NotificationManager.init();
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
    trayManager.addListener(this);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      HotKeyUtil.registerHotkeys(context);
      BrowserExtensionServer.setup(context);
      GitHubStarHandler.handleShowDialog(context);
      handleBriskUpdateCheck(context);
      if (launchedAtStartup) {
        Future.delayed(const Duration(milliseconds: 200), () {
          windowManager.waitUntilReadyToShow(null, () {
            windowManager.hide();
            TrayHandler.setTray(context);
          });
        });
        launchedAtStartup = false;
      }
      WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged =
          TrayHandler.handleSystemThemeChange;
    });
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  void onTrayIconMouseDown() async {
    var isMinimized = await windowManager.isMinimized();
    var isVisible = await windowManager.isVisible();
    var isSkippingTaskbar = await windowManager.isSkipTaskbar();

    if (Platform.isMacOS && (isMinimized || !isVisible || isSkippingTaskbar)) {
      if (isSkippingTaskbar) {
        await windowManager.setSkipTaskbar(false);
      }
      await windowManager.show();
      windowManager.focus();
    }
    if ((Platform.isWindows || Platform.isLinux) && !isVisible) {
      await windowManager.show();
      windowManager.focus();
    }
    super.onTrayIconMouseDown();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu(bringAppToFront: true);
    super.onTrayIconRightMouseDown();
  }

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_window') {
      if (Platform.isMacOS) {
        await windowManager.setSkipTaskbar(false);
      }
      await windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      await windowManager.setPreventClose(false);
      windowManager.close().then((_) => exit(0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueProvider = Provider.of<QueueProvider>(context);
    return LoaderOverlay(
      overlayWidgetBuilder: (progress) => FileInfoLoader(
        onCancelPressed: () => DownloadAdditionUiUtil.cancelRequest(context),
      ),
      child: Scaffold(
        backgroundColor: Colors.black26,
        body: Column(
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SideMenu(),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (queueProvider.queueTopMenu)
                        QueueTopMenu()
                      else if (queueProvider.downloadQueueTopMenu)
                        DownloadQueueTopMenu()
                      else
                        TopMenu(),
                      if (queueProvider.selectedQueueId != null)
                        DownloadGrid()
                      else if (queueProvider.queueTabSelected)
                        DownloadQueueList()
                      else
                        DownloadGrid()
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
