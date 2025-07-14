import 'package:brisk/browser_extension/browser_extension_server.dart';
import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/pluto_grid_check_row_provider.dart';
import 'package:brisk/provider/queue_provider.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/util/auto_updater_util.dart';
import 'package:brisk/util/ui_util.dart';
import 'package:brisk/widget/base/error_dialog.dart';
import 'package:brisk/widget/base/info_dialog.dart';
import 'package:brisk/widget/top_menu/top_menu_util.dart';
import 'package:brisk/provider/pluto_grid_util.dart';
import 'package:brisk/widget/download/add_url_dialog.dart';
import 'package:brisk/widget/top_menu/top_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/download_request_provider.dart';
import '../browser_extension/get_browser_extension_dialog.dart';
import '../queue/add_to_queue_window.dart';

class TopMenu extends StatefulWidget {
  @override
  State<TopMenu> createState() => _TopMenuState();
}

class _TopMenuState extends State<TopMenu> {
  String url = '';

  late DownloadRequestProvider provider;
  late AppLocalizations loc;

  TextEditingController txtController = TextEditingController();

  @override
  void dispose() {
    txtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<DownloadRequestProvider>(context, listen: false);
    final topMenuTheme =
        Provider.of<ThemeProvider>(context).activeTheme.topMenuTheme;
    Provider.of<PlutoGridCheckRowProvider>(context);
    Provider.of<QueueProvider>(context);
    loc = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    return Container(
      width: resolveWindowWidth(size),
      height: topMenuHeight,
      color: topMenuTheme.backgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: TopMenuButton(
              onTap: () => showDialog(
                context: context,
                builder: (_) => AddUrlDialog(),
                barrierDismissible: false,
              ),
              title: loc.addUrl,
              fontSize: 14,
              icon: Icon(
                size: 28,
                Icons.add_rounded,
                color: topMenuTheme.addUrlColor.iconColor,
              ),
              onHoverColor: topMenuTheme.addUrlColor.hoverBackgroundColor,
              textColor: topMenuTheme.addUrlColor.textColor,
            ),
          ),
          TopMenuButton(
            onTap: isDownloadButtonEnabled(provider) ? onDownloadPressed : null,
            title: loc.download,
            fontSize: 14,
            icon: Icon(
              size: 28,
              Icons.download_rounded,
              color: isDownloadButtonEnabled(provider)
                  ? topMenuTheme.downloadColor.iconColor
                  : Color.fromRGBO(79, 79, 79, 0.5),
            ),
            onHoverColor: topMenuTheme.downloadColor.hoverBackgroundColor,
            textColor: isDownloadButtonEnabled(provider)
                ? topMenuTheme.downloadColor.textColor
                : Color.fromRGBO(79, 79, 79, 1),
          ),
          TopMenuButton(
            onTap: isPauseButtonEnabled(provider) ? onStopPressed : null,
            title: loc.stop,
            fontSize: 14,
            icon: Icon(
              size: 28,
              Icons.stop_rounded,
              color: isPauseButtonEnabled(provider)
                  ? topMenuTheme.stopColor.iconColor
                  : Color.fromRGBO(79, 79, 79, 0.5),
            ),
            onHoverColor: topMenuTheme.stopColor.hoverBackgroundColor,
            textColor: isPauseButtonEnabled(provider)
                ? topMenuTheme.stopColor.textColor
                : Color.fromRGBO(79, 79, 79, 1),
          ),
          TopMenuButton(
            onTap: PlutoGridUtil.selectedRowExists
                ? () => PlutoGridUtil.onRemovePressed(context)
                : null,
            title: loc.remove,
            fontSize: 14,
            icon: Icon(
              size: 28,
              Icons.delete,
              color: PlutoGridUtil.selectedRowExists
                  ? topMenuTheme.removeColor.iconColor
                  : disabledButtonColor,
            ),
            onHoverColor: topMenuTheme.removeColor.hoverBackgroundColor,
            textColor: PlutoGridUtil.selectedRowExists
                ? topMenuTheme.removeColor.textColor
                : disabledButtonTextColor,
          ),
          TopMenuButton(
            onTap: PlutoGridUtil.selectedRowExists
                ? () => onAddToQueuePressed(context)
                : null,
            title: loc.addToQueue,
            icon: Icon(
              size: 26,
              Icons.queue,
              color: PlutoGridUtil.selectedRowExists
                  ? topMenuTheme.addToQueueColor.iconColor
                  : disabledButtonColor,
            ),
            fontSize: 13,
            onHoverColor: topMenuTheme.addToQueueColor.hoverBackgroundColor,
            textColor: PlutoGridUtil.selectedRowExists
                ? topMenuTheme.addToQueueColor.textColor
                : disabledButtonTextColor,
          ),
          SizedBox(width: 5),
          // Container(color: Colors.white, width: 1, height: 40),
          TopMenuButton(
            title: loc.getExtension,
            fontSize: 13,
            icon: Icon(
              size: 28,
              Icons.extension,
              color: topMenuTheme.extensionColor.iconColor,
            ),
            onTap: () => showDialog(
              context: context,
              builder: (context) => GetBrowserExtensionDialog(),
            ),
            onHoverColor: topMenuTheme.extensionColor.hoverBackgroundColor,
            textColor: topMenuTheme.extensionColor.textColor,
          ),
          TopMenuButton(
            onTap: () => handleBriskUpdateCheck(
              context,
              showUpdateNotAvailableDialog: true,
              ignoreLastUpdateCheck: true,
            ),
            title: loc.checkForUpdate,
            icon: Icon(
              size: 26,
              Icons.update,
              color: topMenuTheme.checkForUpdateColor.iconColor,
            ),
            fontSize: 12.5,
            onHoverColor: topMenuTheme.addToQueueColor.hoverBackgroundColor,
            textColor: topMenuTheme.checkForUpdateColor.textColor,
          ),
          TopMenuButton(
            title: loc.btn_restart_extension,
            fontSize: 14,
            icon: Icon(
              size: 28,
              Icons.restart_alt_rounded,
              color: topMenuTheme.extensionColor.iconColor,
            ),
            onTap: () => restart_extension(),
            onHoverColor: topMenuTheme.extensionColor.hoverBackgroundColor,
            textColor: topMenuTheme.extensionColor.textColor,
          ),
          // TopMenuButton(
          //   title: 'Discord',
          //   fontSize: 11.5,
          //   icon: SvgPicture.asset(
          //     "assets/icons/discord.svg",
          //     height: 30,
          //     width: 30,
          //     colorFilter: ColorFilter.mode(
          //       Color.fromRGBO(96, 100, 244,1),
          //       BlendMode.srcIn,
          //     ),
          //   ),
          //   onTap: () => launchUrlString(
          //     'https://discord.gg/g8fwgZ84',
          //   ),
          //   onHoverColor: topMenuTheme.extensionColor.hoverBackgroundColor,
          //   textColor: topMenuTheme.extensionColor.textColor,
          // ),
          SizedBox(width: 5),
          // Container(color: Colors.white, width: 1, height: 40),
          // TopMenuButton(
          //   title: 'Build',
          //   icon: Icon(
          //     Icons.extension,
          //     color: Colors.red,
          //   ),
          //   onTap: () {
          //     final dlitem = HiveUtil.instance.downloadItemsBox.getAt(0);
          //     final itemModel = DownloadItemModel.fromDownloadItem(dlitem!);
          //     FileUtil.doooo(itemModel.uid);
          //     assembleFile(
          //         itemModel, SettingsCache.temporaryDir, SettingsCache.saveDir);
          //     print("DONE");
          //   },
          // ),
        ],
      ),
    );
  }

  Color get disabledButtonColor => Color.fromRGBO(79, 79, 79, 0.5);

  Color get disabledButtonTextColor => Color.fromRGBO(79, 79, 79, 1);

  void onMockDownloadPressed(BuildContext context) async {
    // final item = DownloadItem.fromUrl(mockDownloadUrl);
    // item.contentLength = 65945577;
    // item.fileName = "Mozilla.Firefox.zip";
    // item.fileType = DLFileType.compressed.name;
    // item.supportsPause = true;
    // final fileInfo = FileInfo(
    //   item.supportsPause,
    //   item.fileName,
    //   item.contentLength,
    // );
    // DownloadAdditionUiUtil.addDownload(item, fileInfo, context, false);
  }

  void restart_extension() async {
    try {
      await BrowserExtensionServer.restart(context);
      showDialog(
        context: context,
        builder: (context) => InfoDialog(
          titleText: loc.extension_restart_success,
          titleIcon: Icon(Icons.done),
          titleIconBackgroundColor: Colors.lightGreen,
        ),
      );
    } catch (_) {
      showDialog(
        context: context,
        builder: (context) => ErrorDialog(
          width: 450,
          title: loc.extension_restart_failed,
        ),
      );
    }
  }

  void onDownloadPressed() async {
    PlutoGridUtil.doOperationOnCheckedRows((id, _) {
      provider.startDownload(id);
    });
  }

  void onStopPressed() {
    PlutoGridUtil.doOperationOnCheckedRows((id, _) {
      provider.pauseDownload(id);
    });
  }

  void onStopAllPressed() {
    provider.downloads.forEach((id, _) {
      provider.pauseDownload(id);
    });
  }

  void onAddToQueuePressed(BuildContext context) {
    if (PlutoGridUtil.plutoStateManager!.checkedRows.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddToQueueWindow(),
    );
  }
}
