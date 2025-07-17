import 'dart:async';
import 'dart:io';

import 'package:brisk/theme/application_theme.dart';
import 'package:brisk/theme/application_theme_holder.dart';
import 'package:dartx/dartx.dart';
import 'package:path/path.dart';
import 'package:brisk/constants/file_type.dart';
import 'package:brisk/db/hive_util.dart';
import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/pluto_grid_check_row_provider.dart';
import 'package:brisk/provider/queue_provider.dart';
import 'package:brisk/util/file_util.dart';
import 'package:brisk/util/readability_util.dart';
import 'package:brisk/setting/settings_cache.dart';
import 'package:brisk/widget/base/checkbox_confirmation_dialog.dart';
import 'package:brisk/widget/base/delete_confirmation_dialog.dart';
import 'package:brisk/widget/download/queue_schedule_handler.dart';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:provider/provider.dart';

import 'download_request_provider.dart';

class PlutoGridUtil {
  static bool isCtrlKeyDown = false;
  static bool isShiftKeyDown = false;

  static PlutoGridStateManager? _stateManager;
  static PlutoGridStateManager? _multiDownloadAdditionStateManager;

  static Timer? cacheClearTimer;
  static final List<PlutoRow> cachedRows = [];

  static Map<String, Function(PlutoRow)> filters = {};

  static String? _fileNameSearchQuery;

  static PlutoGridConfiguration config(DownloadGridTheme downloadGridTheme) {
    return ApplicationThemeHolder.activeTheme.isLight
        ? PlutoGridConfiguration(
            style: PlutoGridStyleConfig(
              oddRowColor: downloadGridTheme.backgroundColor,
              evenRowColor: downloadGridTheme.backgroundColor,
              columnTextStyle: TextStyle(
                fontWeight: FontWeight.w500,
                color: downloadGridTheme.rowTextColor,
              ),
              activatedBorderColor: Colors.transparent,
              borderColor: downloadGridTheme.borderColor,
              gridBorderColor: downloadGridTheme.borderColor,
              activatedColor: downloadGridTheme.activeRowColor,
              gridBackgroundColor: downloadGridTheme.backgroundColor,
              rowColor: downloadGridTheme.rowColor,
              checkedColor: downloadGridTheme.checkedRowColor,
            ),
          )
        : PlutoGridConfiguration(
            style: PlutoGridStyleConfig.dark(
              oddRowColor: downloadGridTheme.backgroundColor,
              evenRowColor: downloadGridTheme.backgroundColor,
              columnTextStyle: TextStyle(
                fontWeight: FontWeight.w500,
                color: downloadGridTheme.rowTextColor,
              ),
              activatedBorderColor: Colors.transparent,
              borderColor: downloadGridTheme.borderColor,
              gridBorderColor: downloadGridTheme.borderColor,
              activatedColor: downloadGridTheme.activeRowColor,
              gridBackgroundColor: downloadGridTheme.backgroundColor,
              rowColor: downloadGridTheme.rowColor,
              checkedColor: downloadGridTheme.checkedRowColor,
            ),
          );
  }

  static void handleRowSelection(
    event,
    PlutoGridStateManager stateManager,
    PlutoGridCheckRowProvider? plutoProvider,
  ) {
    if (!PlutoGridUtil.isCtrlKeyDown && !PlutoGridUtil.isShiftKeyDown) {
      stateManager.checkedRows.forEach((row) {
        if (row.checkedViaSelect != null && row.checkedViaSelect!) {
          stateManager.setRowChecked(row, false, checkedViaSelect: false);
        }
      });
    }
    if (stateManager.checkedRows.contains(event.row!)) {
      stateManager.setRowChecked(
        event.row!,
        false,
        checkedViaSelect: true,
      );
    } else {
      if (PlutoGridUtil.isCtrlKeyDown) {
        stateManager.setRowChecked(
          event.row!,
          true,
          checkedViaSelect: true,
        );
      } else if (PlutoGridUtil.isShiftKeyDown) {
        final selectedRow = stateManager.checkedRows.first;
        final selectedRowIdx = stateManager.refRows.indexOf(selectedRow);
        final targetRowIdx = stateManager.refRows.indexOf(event.row!);
        final rowsToCheck = selectedRowIdx > targetRowIdx
            ? stateManager.refRows.sublist(targetRowIdx, selectedRowIdx)
            : stateManager.refRows.sublist(selectedRowIdx, targetRowIdx + 1);
        for (final row in rowsToCheck) {
          stateManager.setRowChecked(
            row,
            true,
            checkedViaSelect: true,
          );
        }
      } else {
        stateManager.setRowChecked(
          event.row!,
          true,
          checkedViaSelect: true,
        );
      }
    }
    stateManager.notifyListeners();
    plutoProvider?.notifyListeners();
  }

  static void updateRowCells(DownloadProgressMessage progress) {
    final id = progress.downloadItem.id!;
    final row = findCachedRow(id) ?? findRowById(id);
    if (row == null) return;
    final cells = row.cells;
    final downloadItem = progress.downloadItem;
    if (progress.status == DownloadStatus.canceled) {
      downloadItem.status = DownloadStatus.canceled;
    }
    updateCells(cells, progress, downloadItem);
    for (PlutoRow row
        in QueueScheduleHandler.queueRows.values.expand((list) => list)) {
      if (id == row.cells['id']!.value) {
        updateCells(row.cells, progress, downloadItem);
      }
    }
    _stateManager?.notifyListeners();
    _runPeriodicCachedRowClear();
  }

  static void updateCells(
    Map<String, PlutoCell> cells,
    DownloadProgressMessage progress,
    DownloadItemModel downloadItem,
  ) {
    cells["file_name"]?.value = progress.downloadItem.fileName;
    cells["time_left"]?.value = progress.estimatedRemaining;
    cells["progress"]?.value =
        convertPercentageNumberToReadableStr(progress.downloadProgress * 100);
    cells["transfer_rate"]?.value = progress.transferRate;
    cells["status"]?.value = downloadItem.status;
    cells["finish_date"]?.value = downloadItem.finishDate ?? "";
    if (progress.assembledFileSize != null) {
      cells["size"]?.value =
          convertByteToReadableStr(progress.assembledFileSize!);
    }
  }

  static void _runPeriodicCachedRowClear() {
    if (cacheClearTimer != null) return;
    cacheClearTimer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) => cachedRows.clear(),
    );
  }

  static Widget fileNameColumnRenderer(
    PlutoColumnRendererContext rendererContext,
    ApplicationTheme theme,
  ) {
    final fileName = rendererContext.row.cells["file_name"]!.value;
    final fileType = FileUtil.detectFileType(fileName);
    String? strBeforeSearch;
    String? strMatchSearch;
    String? strAfterSearch;
    if (_fileNameSearchQuery != null) {
      int index =
          fileName.toLowerCase().indexOf(_fileNameSearchQuery!.toLowerCase());
      if (index >= 0) {
        strBeforeSearch = fileName.toString().substring(0, index);
        strMatchSearch = fileName
            .toString()
            .substring(index, index + _fileNameSearchQuery!.length);
        strAfterSearch =
            fileName.toString().substring(index + _fileNameSearchQuery!.length);
      }
    }
    return Padding(
      padding: const EdgeInsets.only(left: 5.0),
      child: Row(
        children: [
          SizedBox(
            width: resolveIconSize(fileType),
            height: resolveIconSize(fileType),
            child: SvgPicture.asset(
              FileUtil.resolveFileTypeIconPath(fileType.name),
              colorFilter: ColorFilter.mode(
                FileUtil.resolveFileTypeIconColor(fileType.name),
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 5),
          if (strMatchSearch != null)
            Expanded(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    if (strBeforeSearch != null)
                      TextSpan(
                        text: strBeforeSearch,
                        style: TextStyle(
                          color: theme.downloadGridTheme.rowTextColor,
                          fontWeight: theme.fontWeight,
                        ),
                      ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(238, 197, 25, 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          strMatchSearch,
                          style: TextStyle(
                            color: theme.downloadGridTheme.rowTextColor,
                            fontWeight: theme.fontWeight,
                          ),
                        ),
                      ),
                    ),
                    if (strAfterSearch != null)
                      TextSpan(
                        text: strAfterSearch,
                        style: TextStyle(
                          color: theme.downloadGridTheme.rowTextColor,
                          fontWeight: theme.fontWeight,
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Text(
                rendererContext.row.cells[rendererContext.column.field]!.value
                    .toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.downloadGridTheme.rowTextColor,
                  fontWeight: theme.fontWeight,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static double resolveIconSize(DLFileType fileType) {
    if (fileType == DLFileType.documents || fileType == DLFileType.program)
      return 25;
    else if (fileType == DLFileType.music)
      return 28;
    else
      return 30;
  }

  static void removeCachedRow(int id) {
    cachedRows.removeWhere((row) => row.cells["id"]?.value == id);
  }

  static PlutoRow? findCachedRow(int id) {
    final results = cachedRows.where((row) => row.cells["id"]?.value == id);
    if (results.length != 1) return null;
    return results.first;
  }

  static PlutoRow? findRowById(int id) {
    final results =
        _stateManager?.rows.where((row) => row.cells["id"]?.value == id);
    if (results == null || results.length != 1) return null;
    cachedRows.add(results.first);
    return results.first;
  }

  static void setStateManager(PlutoGridStateManager plutoStateManager) {
    _stateManager = plutoStateManager;
  }

  static void setMultiAdditionStateManager(
    PlutoGridStateManager plutoStateManager,
  ) {
    _multiDownloadAdditionStateManager = plutoStateManager;
  }

  static void setSavedFilters() {
    final combinedFilter = (row) => filters.values.every((fn) => fn(row));
    _stateManager?.setFilter(combinedFilter);
    _stateManager?.notifyListeners();
  }

  static void addFilter(
    String cellName,
    String filterValue, {
    bool negate = false,
  }) {
    Function(PlutoRow) filter = (row) {
      final cellValue = row.cells[cellName]?.value;
      return negate ? cellValue != filterValue : cellValue == filterValue;
    };
    filters[(filters.length + 1).toString()] = filter;
    setSavedFilters();
  }

  static void addSearchFilter(String filterValue) {
    if (filterValue.isBlank) {
      _fileNameSearchQuery = null;
      filters.remove('search');
      setSavedFilters();
      return;
    }
    final searchFilter = (row) {
      final cellValue = row.cells['file_name']?.value;
      return cellValue != null &&
          cellValue.toString().toLowerCase().contains(filterValue.trim());
    };
    _fileNameSearchQuery = filterValue.trim();
    filters['search'] = searchFilter;
    setSavedFilters();
  }

  static void registerKeyListeners(
    PlutoGridStateManager stateManager, {
    VoidCallback? onDeletePressed,
  }) {
    stateManager.keyManager!.subject.stream.listen((event) {
      if (event.event.logicalKey == LogicalKeyboardKey.controlLeft ||
          event.event.logicalKey == LogicalKeyboardKey.controlRight) {
        if (event.isKeyDownEvent) {
          isCtrlKeyDown = true;
        }
        if (event.isKeyUpEvent) {
          isCtrlKeyDown = false;
        }
      }
      if (event.event.logicalKey == LogicalKeyboardKey.shiftLeft ||
          event.event.logicalKey == LogicalKeyboardKey.shiftRight) {
        if (event.isKeyDownEvent) {
          isShiftKeyDown = true;
        }
        if (event.isKeyUpEvent) {
          isShiftKeyDown = false;
        }
      }
      if (event.isKeyDownEvent &&
          event.event.logicalKey == LogicalKeyboardKey.delete) {
        onDeletePressed?.call();
      }
      if (event.event.physicalKey == PhysicalKeyboardKey.keyA &&
          isCtrlKeyDown) {
        stateManager.refRows.forEach((row) {
          stateManager.setRowChecked(
            row,
            true,
            checkedViaSelect: true,
          );
        });
      }
    });
  }

  static void removeFilters() {
    filters.clear();
    _fileNameSearchQuery = null;
    _stateManager?.setFilter(null);
    _stateManager?.notifyListeners();
  }

  static int getFilteredRowCount(String cell, String value,
      {bool negate = false}) {
    return _stateManager?.rows.where((row) {
          final cellValue = row.cells[cell]?.value;
          return negate ? cellValue != value : cellValue == value;
        }).length ??
        0;
  }

  static bool get selectedRowExists => !selectedRowIds.isEmpty;

  static List<int> get selectedRowIds => _stateManager?.checkedRows == null
      ? []
      : _stateManager!.checkedRows
          .map((row) => int.parse(row.cells["id"]!.value.toString()))
          .toList();

  static void doOperationOnCheckedRows(
      Function(int id, PlutoRow row) operation) {
    final selectedRows = _stateManager?.checkedRows;
    if (selectedRows == null) return;
    for (var row in selectedRows) {
      final id = row.cells["id"]!.value;
      _stateManager?.setRowChecked(row, false);
      operation(id, row);
    }
    _stateManager?.notifyListeners();
  }

  static void onRemovePressed(BuildContext context) {
    final provider =
        Provider.of<DownloadRequestProvider>(context, listen: false);
    final queueProvider = Provider.of<QueueProvider>(context, listen: false);
    final stateManager = PlutoGridUtil.plutoStateManager;
    if (stateManager!.checkedRows.isEmpty) return;
    if (queueProvider.selectedQueueId != null) {
      showDialog(
        context: context,
        builder: (context) => DeleteConfirmationDialog(
          title:
              "Are you sure you want to remove the selected downloads from the queue?",
          onConfirmPressed: () async {
            final queue = HiveUtil.instance.downloadQueueBox
                .get(queueProvider.selectedQueueId)!;
            if (queue.downloadItemsIds == null) return;
            PlutoGridUtil.doOperationOnCheckedRows((id, row) async {
              queue.downloadItemsIds!.removeWhere((dlId) => dlId == id);
              PlutoGridUtil.plutoStateManager?.removeRows([row]);
            });
            await queue.save();
            PlutoGridUtil.plutoStateManager?.notifyListeners();
          },
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => CheckboxConfirmationDialog(
        onConfirmPressed: (deleteFile) {
          PlutoGridUtil.doOperationOnCheckedRows((id, row) {
            deleteOnCheckedRows(row, id, deleteFile, provider);
          });
          stateManager.notifyListeners();
        },
        title: AppLocalizations.of(context)!.downloadDeletionConfirmation,
        checkBoxTitle: AppLocalizations.of(context)!.deleteDownloadedFiles,
      ),
    );
  }

  static void deleteOnCheckedRows(
    PlutoRow row,
    int id,
    bool deleteFile,
    DownloadRequestProvider provider,
  ) async {
    final downloadItem = HiveUtil.instance.downloadItemsBox.get(id)!;
    PlutoGridUtil.plutoStateManager!.removeRows([row]);
    if (deleteFile) {
      final file = File(downloadItem.filePath);
      if (file.existsSync()) {
        file.delete();
      }
    }
    final logPath = join(
      SettingsCache.temporaryDir.path,
      "Logs",
      "${downloadItem.uid}_logs.log",
    );
    if (File(logPath).existsSync()) {
      File(logPath).deleteSync();
    }
    HiveUtil.instance.downloadItemsBox.delete(id);
    HiveUtil.instance.removeDownloadFromQueues(id);
    provider.downloads.removeWhere((key, _) => key == id);
    DownloadEngine.terminate(downloadItem.uid)
        .then((_) => FileUtil.deleteDownloadTempDirectory(downloadItem.uid));
  }

  static PlutoGridStateManager? get plutoStateManager => _stateManager;

  static PlutoGridStateManager? get multiDownloadAdditionStateManager =>
      _multiDownloadAdditionStateManager;
}
