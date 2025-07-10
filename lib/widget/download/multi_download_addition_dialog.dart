import 'dart:io';

import 'package:brisk/db/hive_util.dart';
import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/model/download_item.dart';
import 'package:brisk/model/file_metadata.dart';
import 'package:brisk/provider/pluto_grid_util.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/util/download_addition_ui_util.dart';
import 'package:brisk/util/download_engine_util.dart';
import 'package:brisk/setting/settings_cache.dart';
import 'package:brisk/widget/base/error_dialog.dart';
import 'package:brisk/widget/base/outlined_text_field.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:brisk/widget/base/scrollable_dialog.dart';
import 'package:brisk/widget/download/multi_download_addition_grid.dart';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:dartx/dartx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;

import '../../provider/download_request_provider.dart';
import '../../util/file_util.dart';

class MultiDownloadAdditionDialog extends StatefulWidget {
  List<FileInfo> fileInfos = [];
  late DownloadRequestProvider provider;
  bool checkboxEnabled = false;

  MultiDownloadAdditionDialog(this.fileInfos);

  @override
  State<MultiDownloadAdditionDialog> createState() =>
      _MultiDownloadAdditionDialogState();
}

class _MultiDownloadAdditionDialogState
    extends State<MultiDownloadAdditionDialog> {
  late AppLocalizations loc;
  TextEditingController savePathController = TextEditingController();

  @override
  void dispose() {
    savePathController.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    widget.provider =
        Provider.of<DownloadRequestProvider>(context, listen: false);
    final theme =
        Provider.of<ThemeProvider>(context).activeTheme.alertDialogTheme;
    final size = MediaQuery.of(context).size;
    loc = AppLocalizations.of(context)!;
    return ScrollableDialog(
      title: Padding(
        padding: const EdgeInsets.all(15),
        child: Text(
          loc.addDownload,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      width: 600,
      height: 500,
      scrollButtonVisible: true,
      scrollviewHeight: 500,
      scrollViewWidth: 600,
      backgroundColor: theme.backgroundColor,
      content: Container(
        height: 500,
        width: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 600,
              decoration: BoxDecoration(
                // borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Color.fromRGBO(220, 220, 220, 0.2)),
              ),
              child: SingleChildScrollView(
                child: Container(
                  height: resolveMainContainerHeight(size),
                  width: 600,
                  child: MultiDownloadAdditionGrid(
                    onDeleteKeyPressed: onDeleteKeyPressed,
                    files: widget.fileInfos,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2.0),
                        ),
                        side: WidgetStateBorderSide.resolveWith(
                          (states) =>
                              BorderSide(width: 1.0, color: Colors.grey),
                        ),
                        activeColor: Colors.blueGrey,
                        value: widget.checkboxEnabled,
                        onChanged: (value) =>
                            setState(() => widget.checkboxEnabled = value!),
                      ),
                      Text(
                        loc.customSavePath,
                        style: TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: OutLinedTextField(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            enabled: widget.checkboxEnabled,
                            controller: savePathController,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      RoundedOutlinedButton(
                        mainAxisAlignment: MainAxisAlignment.center,
                        text: null,
                        height: 40,
                        width: 56,
                        icon: SvgPicture.asset(
                          'assets/icons/folder-open.svg',
                          colorFilter:
                              ColorFilter.mode(Colors.white54, BlendMode.srcIn),
                        ),
                        textColor: Colors.white,
                        borderColor: Colors.transparent,
                        backgroundColor: theme.itemContainerBackgroundColor,
                        onPressed: widget.checkboxEnabled
                            ? onSelectSavePathPressed
                            : null,
                      )
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
      buttons: [
        RoundedOutlinedButton.fromButtonColor(
          theme.cancelButtonColor,
          onPressed: () => Navigator.of(context).pop(),
          text: loc.btn_cancel,
        ),
        const SizedBox(width: 10),
        RoundedOutlinedButton.fromButtonColor(
          theme.addButtonColor,
          onPressed: onAddPressed,
          text: loc.btn_add,
        ),
      ],
    );
  }

  void onDeleteKeyPressed() {
    setState(() {
      PlutoGridUtil.multiDownloadAdditionStateManager!.checkedRows
          .forEach((row) {
        final fileName = row.cells["file_name"]!.value;
        widget.fileInfos.removeWhere((f) => f.fileName == fileName);
      });
    });
  }

  List<FileInfo> getOrderedFileInfos() {
    final fileNamesOrdered = PlutoGridUtil
        .multiDownloadAdditionStateManager!.rows
        .map((r) => r.cells["file_name"]!.value)
        .toList();
    List<FileInfo> fileInfos = [];
    for (final fileName in fileNamesOrdered) {
      fileInfos.add(
        widget.fileInfos.where((f) => f.fileName == fileName).first,
      );
    }
    return fileInfos;
  }

  void onSelectSavePathPressed() async {
    final customSavePath = await FilePicker.platform.getDirectoryPath(
      initialDirectory: SettingsCache.saveDir.path,
    );
    if (customSavePath != null) {
      setState(() => savePathController.text = customSavePath);
    }
  }

  void onAddPressed() async {
    if (savePathExists && !Directory(savePathController.text).existsSync()) {
      showDialog(
        context: context,
        builder: (context) => ErrorDialog(
          title: loc.err_invalidPath_title,
          description: loc.err_invalidPath_savePath_description,
          descriptionHint: loc.err_invalidPath_descriptionHint,
          height: 180,
          width: 380,
        ),
      );
      return;
    }
    final downloadItems =
        getOrderedFileInfos().map((e) => DownloadItem.fromFileInfo(e)).toList();
    await updateDuplicateUrls(downloadItems);
    for (final item in downloadItems.toSet()) {
      final rule = SettingsCache.fileSavePathRules.firstOrNullWhere(
        (rule) => rule.isSatisfiedByDownloadItem(item),
      );
      if (savePathExists) {
        item.filePath = path.join(savePathController.text, item.fileName);
      } else if (rule != null) {
        item.filePath = FileUtil.getFilePath(
          item.fileName,
          baseSaveDir: Directory(rule.savePath),
          useTypeBasedSubDirs: false,
        );
      }
      await HiveUtil.instance.addDownloadItem(item);
      widget.provider.insertRows([
        DownloadProgressMessage(
          downloadItem: buildFromDownloadItem(item),
        )
      ]);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> updateDuplicateUrls(List<DownloadItem> downloadItems) async {
    final duplicates = downloadItems.where(checkDownloadDuplication).toList();
    final uncompletedDownloads = HiveUtil.instance.downloadItemsBox.values
        .where((element) => element.status != DownloadStatus.assembleComplete);
    for (final download in uncompletedDownloads) {
      final fileNames = duplicates.map((e) => e.fileName).toList();
      if (fileNames.contains(download.fileName)) {
        download.downloadUrl = duplicates
            .where((dl) => dl.fileName == download.fileName)
            .first
            .downloadUrl;
        await download.save();
      }
    }
    downloadItems.removeWhere(checkDownloadDuplication);
  }

  bool get savePathExists =>
      widget.checkboxEnabled && savePathController.text.isNotNullOrBlank;

  bool checkDownloadDuplication(DownloadItem item) {
    return DownloadAdditionUiUtil.checkDownloadDuplication(item.fileName);
  }

  double resolveScrollViewHeight(Size size) {
    return 400;
  }

  double resolveMainContainerHeight(Size size) {
    return 400;
  }

  double resolveListContainerWidth(Size size) {
    if (size.width > 700) {
      return 450;
    }
    return size.width * 0.5;
  }
}
