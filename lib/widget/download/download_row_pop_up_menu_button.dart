import 'package:brisk/widget/download/download_progress_dialog.dart';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brisk/util/url_launcher_util.dart';
import 'package:brisk/util/file_util.dart';
import 'package:brisk/db/hive_util.dart';
import 'package:brisk/provider/download_request_provider.dart';
import 'add_url_dialog.dart';
import 'download_info_dialog.dart';

class DownloadRowPopUpMenuButton extends StatelessWidget {
  final String status;
  final int id;

  DownloadRowPopUpMenuButton({
    Key? key,
    required this.status,
    required this.id,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: const Icon(
        Icons.more_vert_rounded,
        color: Colors.white,
      ),
      color: const Color.fromRGBO(48, 48, 48, 1),
      tooltip: "",
      onSelected: (value) => onPopupMenuItemSelected(value, id, context),
      itemBuilder: (BuildContext bc) {
        final provider =
            Provider.of<DownloadRequestProvider>(bc, listen: false);
        final downloadProgress = provider.downloads[id];
        final downloadExists = downloadProgress != null;
        final downloadComplete = status == DownloadStatus.assembleComplete;
        final updateUrlEnabled = downloadExists
            ? (downloadProgress.status != DownloadStatus.assembleComplete ||
                downloadProgress.status != DownloadStatus.downloading)
            : (status != DownloadStatus.assembleComplete ||
                status != DownloadStatus.downloading);
        return [
          PopupMenuItem(
              value: 2,
              enabled: downloadExists,
              child: getPopupMenuText(
                "Open progress window",
                downloadExists,
              )),
          PopupMenuItem(
            value: 3,
            child: getPopupMenuText("Properties", true),
          ),
          PopupMenuItem(
            value: 4,
            enabled: downloadComplete,
            child: getPopupMenuText("Open file", downloadComplete),
          ),
          PopupMenuItem(
            value: 5,
            enabled: downloadComplete,
            child: getPopupMenuText(
              "Open file location",
              downloadComplete,
            ),
          ),
          PopupMenuItem(
            value: 1,
            enabled: updateUrlEnabled,
            child: !updateUrlEnabled
                ? Tooltip(
                    message: "Download must be paused",
                    child: getPopupMenuText(
                      "Update URL",
                      updateUrlEnabled,
                    ),
                  )
                : getPopupMenuText("Update URL", updateUrlEnabled),
          ),
        ];
      },
    );
  }

  Widget getPopupMenuText(String text, bool enabled) => Text(text,
      style: TextStyle(
        color: enabled ? Colors.white : Colors.grey,
      ));

  void onPopupMenuItemSelected(int value, int id, BuildContext context) {
    final dl = HiveUtil.instance.downloadItemsBox.get(id)!;
    switch (value) {
      case 1:
        showDialog(
          context: context,
          builder: (context) =>
              AddUrlDialog(downloadId: id, updateDialog: true),
        );
        break;
      case 2:
        showDialog(
          context: context,
          builder: (_) => DownloadProgressDialog(id),
          barrierDismissible: false,
        );
        break;
      case 3:
        showDialog(
          context: context,
          builder: (context) =>
              DownloadInfoDialog(dl, showActionButtons: false),
        );
        break;
      case 4:
        openUrl("file:${dl.filePath}");
        break;
      case 5:
        openFileLocation(dl);
        break;
    }
  }
}
