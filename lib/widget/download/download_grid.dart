import 'package:brisk/browser_extension/browser_extension_server.dart';
import 'package:brisk/constants/file_type.dart';
import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/download_request_provider.dart';
import 'package:brisk/provider/pluto_grid_check_row_provider.dart';
import 'package:brisk/provider/pluto_grid_util.dart';
import 'package:brisk/provider/queue_provider.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/util/file_util.dart';
import 'package:brisk/util/responsive_util.dart';
import 'package:brisk/util/ui_util.dart';
import 'package:brisk/widget/download/add_url_dialog.dart';
import 'package:brisk/widget/download/download_info_dialog.dart';
import 'package:brisk/widget/download/download_progress_dialog.dart';
import 'package:brisk/widget/other/automatic_url_update_dialog.dart';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:brisk/db/hive_util.dart';

class DownloadGrid extends StatefulWidget {
  @override
  State<DownloadGrid> createState() => _DownloadGridState();
}

class _DownloadGridState extends State<DownloadGrid> {
  late List<PlutoColumn> columns;
  DownloadRequestProvider? provider;
  QueueProvider? queueProvider;
  PlutoGridCheckRowProvider? plutoProvider;
  late AppLocalizations loc;

  @override
  void didChangeDependencies() {
    loc = AppLocalizations.of(context)!;
    initColumns(context);
    super.didChangeDependencies();
  }

  void initColumns(BuildContext context) {
    columns = [
      PlutoColumn(
        readOnly: true,
        hide: true,
        width: 80,
        title: 'Id',
        field: 'id',
        type: PlutoColumnType.number(),
      ),
      PlutoColumn(
        readOnly: true,
        hide: true,
        width: 80,
        title: 'Uid',
        field: 'uid',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        enableRowChecked: true,
        width: 400,
        title: loc.fileName,
        field: 'file_name',
        type: PlutoColumnType.text(),
        renderer: (rendererContext) {
          final fileName = rendererContext.row.cells["file_name"]!.value;
          final fileType = FileUtil.detectFileType(fileName);
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
                Expanded(
                  child: Text(
                    rendererContext
                        .row.cells[rendererContext.column.field]!.value
                        .toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      PlutoColumn(
        readOnly: true,
        width: 85,
        title: loc.size,
        field: 'size',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        readOnly: true,
        width: 100,
        title: loc.progress,
        field: 'progress',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        readOnly: true,
        width: 130,
        title: loc.status,
        field: "status",
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        readOnly: true,
        enableSorting: false,
        width: 125,
        title: loc.speed,
        field: 'transfer_rate',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        readOnly: true,
        width: 120,
        title: loc.timeLeft,
        field: 'time_left',
        type: PlutoColumnType.text(),
      ),
      PlutoColumn(
        readOnly: true,
        width: 105,
        title: loc.startDate,
        field: 'start_date',
        type: PlutoColumnType.date(),
      ),
      PlutoColumn(
        readOnly: true,
        width: 115,
        title: loc.finishDate,
        field: 'finish_date',
        type: PlutoColumnType.date(),
      ),
      PlutoColumn(
        readOnly: true,
        hide: true,
        width: 120,
        title: 'File Type',
        field: 'file_type',
        type: PlutoColumnType.text(),
      )
    ];
  }

  double resolveIconSize(DLFileType fileType) {
    if (fileType == DLFileType.documents || fileType == DLFileType.program)
      return 25;
    else if (fileType == DLFileType.music)
      return 28;
    else
      return 30;
  }

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<DownloadRequestProvider>(context, listen: false);
    final downloadGridTheme =
        Provider.of<ThemeProvider>(context).activeTheme.downloadGridTheme;
    plutoProvider = Provider.of<PlutoGridCheckRowProvider>(
      context,
      listen: false,
    );
    queueProvider = Provider.of<QueueProvider>(context);
    final size = MediaQuery.of(context).size;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: size.height - topMenuHeight,
        width: resolveWindowWidth(size),
        decoration: const BoxDecoration(color: Colors.black26),
        child: PlutoGrid(
          key: ValueKey(queueProvider?.selectedQueueId ?? 'download-grid'),
          mode: PlutoGridMode.selectWithOneTap,
          configuration: PlutoGridConfiguration(
            style: PlutoGridStyleConfig.dark(
              activatedBorderColor: Colors.transparent,
              borderColor: downloadGridTheme.borderColor,
              gridBorderColor: downloadGridTheme.borderColor,
              activatedColor: downloadGridTheme.activeRowColor,
              gridBackgroundColor: downloadGridTheme.backgroundColor,
              rowColor: downloadGridTheme.rowColor,
              checkedColor: downloadGridTheme.checkedRowColor,
            ),
          ),
          columns: columns,
          rows: [],
          onSelected: (event) => PlutoGridUtil.handleRowSelection(
            event,
            PlutoGridUtil.plutoStateManager!,
            plutoProvider,
          ),
          onRowChecked: (row) => plutoProvider?.notifyListeners(),
          onRowDoubleTap: onRowDoubleTap,
          onLoaded: (event) => onLoaded(event, provider!, queueProvider!),
          onRowSecondaryTap: (event) => showSecondaryTapMenu(context, event),
        ),
      ),
    );
  }

  void showSecondaryTapMenu(
    BuildContext context,
    PlutoGridOnRowSecondaryTapEvent event,
  ) {
    final provider =
        Provider.of<DownloadRequestProvider>(context, listen: false);
    final size = MediaQuery.of(context).size;
    final loc = AppLocalizations.of(context)!;
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final id = event.row.cells["id"]!.value;
    final status = event.row.cells["status"]!.value;
    final downloadProgress = provider.downloads[id];
    final downloadExists = downloadProgress != null;
    final downloadComplete = status == DownloadStatus.assembleComplete;
    final updateUrlEnabled = downloadExists
        ? (downloadProgress.status != DownloadStatus.assembleComplete ||
            downloadProgress.status != DownloadStatus.downloading)
        : (!downloadComplete || status == DownloadStatus.paused);
    final automaticUrlUpdateEnabled = updateUrlEnabled &&
        HiveUtil.instance.downloadItemsBox.get(id)?.referer != null;
    showMenu(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
      ),
      color: theme.activeTheme.rightClickMenuBackgroundColor,
      popUpAnimationStyle: AnimationStyle(
        curve: Easing.emphasizedAccelerate,
        duration: Durations.short2,
      ),
      context: context,
      position: Directionality.of(context) == TextDirection.rtl
          ? RelativeRect.fromDirectional(
              textDirection: TextDirection.rtl,
              bottom: event.offset.dy,
              top: event.offset.dy,
              end: size.width - event.offset.dx,
              start: size.width - event.offset.dx,
            )
          : RelativeRect.fromLTRB(
              event.offset.dx,
              event.offset.dy,
              event.offset.dx,
              event.offset.dy,
            ),
      items: [
        PopupMenuItem(
          value: "Show Progress",
          child: Text(loc.popupMenu_showProgress),
          enabled: downloadExists,
        ),
        PopupMenuItem(
          value: "Open File",
          child: Text(loc.btn_openFile),
          enabled: downloadComplete,
        ),
        PopupMenuItem(
          value: "Open File Location",
          child: Text(loc.btn_openFileLocation),
          enabled: downloadComplete,
        ),
        PopupMenuItem(
          value: "Update URL",
          child: Text(loc.btn_updateUrl),
          enabled: updateUrlEnabled,
        ),
        PopupMenuItem(
          value: "Automatic URL Update",
          child: Text(loc.automaticUrlUpdate),
          enabled: automaticUrlUpdateEnabled,
        ),
        PopupMenuItem(
          value: "Properties",
          child: Text(loc.popupMenu_properties),
        ),
      ],
    ).then((value) => onMenuItemClicked(value, event));
  }

  void onMenuItemClicked(String? value, PlutoGridOnRowSecondaryTapEvent event) {
    if (value == null) {
      return;
    }
    final downloadId = event.row.cells["id"]!.value;
    final downloadItem = HiveUtil.instance.downloadItemsBox.get(downloadId);
    if (downloadItem == null) {
      return;
    }
    switch (value) {
      case "Show Progress":
        showDialog(
          context: context,
          builder: (_) => DownloadProgressDialog(downloadItem.key),
          barrierDismissible: false,
        );
        break;
      case "Open File":
        launchUrlString("file:${downloadItem.filePath}");
        break;
      case "Open File Location":
        openFileLocation(downloadItem);
        break;
      case "Update URL":
        showDialog(
          context: context,
          builder: (context) =>
              AddUrlDialog(downloadId: downloadItem.key, updateDialog: true),
        );
        break;
      case "Automatic URL Update":
        launchUrlString(downloadItem.referer!);
        BrowserExtensionServer.awaitingUpdateUrlItem = downloadItem;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AutomaticUrlUpdateDialog(),
        );
        break;
      case "Properties":
        showDialog(
          context: context,
          builder: (context) => DownloadInfoDialog(
            downloadItem,
            showActionButtons: false,
            showFileActionButtons:
                downloadItem.status == DownloadStatus.assembleComplete,
          ),
        );
        break;
      default:
        break;
    }
  }

  void onLoaded(
    event,
    DownloadRequestProvider provider,
    QueueProvider queueProvider,
  ) async {
    PlutoGridUtil.setStateManager(event.stateManager);
    PlutoGridUtil.plutoStateManager
        ?.setSelectingMode(PlutoGridSelectingMode.row);
    PlutoGridUtil.registerKeyListeners(
      PlutoGridUtil.plutoStateManager!,
      onDeletePressed: () => PlutoGridUtil.onRemovePressed(context),
    );
    if (queueProvider.selectedQueueId == null) {
      provider.fetchRows(HiveUtil.instance.downloadItemsBox.values.toList());
    } else {
      final queueId = queueProvider.selectedQueueId!;
      final queue = await HiveUtil.instance.downloadQueueBox.get(queueId);
      if (queue?.downloadItemsIds == null) return;
      final downloads = queue!.downloadItemsIds!
          .map((e) => HiveUtil.instance.downloadItemsBox.get(e)!)
          .toList();
      provider.fetchRows(downloads);
    }
    PlutoGridUtil.plutoStateManager!.setFilter(PlutoGridUtil.filter);
  }

  void onRowDoubleTap(event) {
    final status = event.row.cells["status"]?.value;
    final id = event.row.cells["id"]?.value;
    final downloadItem = HiveUtil.instance.downloadItemsBox.get(id);
    final downloadProgress = provider!.downloads[id];
    if (status == null || downloadItem == null) {
      return;
    }
    if (downloadProgress != null &&
        downloadProgress.status != DownloadStatus.assembleComplete) {
      showDialog(
        context: context,
        builder: (_) => DownloadProgressDialog(id),
        barrierDismissible: false,
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => DownloadInfoDialog(
        downloadItem,
        showActionButtons: false,
        newDownload: false,
        showFileActionButtons:
            downloadItem.status == DownloadStatus.assembleComplete,
      ),
    );
  }
}
