import 'package:brisk/constants/speed_unit.dart';
import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/download_request_provider.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/theme/application_theme.dart';
import 'package:brisk/util/readability_util.dart';
import 'package:brisk/widget/base/default_tooltip.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:brisk/widget/base/scrollable_dialog.dart';
import 'package:brisk/widget/download/queue_schedule_handler.dart';
import 'package:brisk/widget/download/segment_progress_bar.dart';
import 'package:brisk/widget/download/speed_limit_panel.dart';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DownloadProgressDialog extends StatefulWidget {
  final int downloadId;

  DownloadProgressDialog(this.downloadId);

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

/// The panels that can be expanded below the download stats.
enum _DetailsTab { connections, speedLimit }

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  _DetailsTab? openTab;

  bool get showDetails => openTab != null;

  /// The speed limit panel only has a status line and one row of controls, so it is shorter
  /// than the connection list. The status line gets a second line when a global limit is set.
  double get detailsPanelHeight {
    switch (openTab) {
      case _DetailsTab.connections:
        return 200;
      case _DetailsTab.speedLimit:
        return KasmaDownloadEngine.globalSpeedLimit > 0 ? 126 : 105;
      case null:
        return 0;
    }
  }

  void toggleTab(_DetailsTab tab) {
    setState(() => openTab = openTab == tab ? null : tab);
  }

  bool showDetailAvailable = true;
  late Size size;
  late ApplicationTheme theme;
  late DownloadRequestProvider provider;
  late AppLocalizations loc;

  List<SegmentProgress> lastSegments = [];

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<DownloadRequestProvider>(context, listen: false);
    theme = Provider.of<ThemeProvider>(context).activeTheme;
    size = MediaQuery.of(context).size;
    final downloadProgress = provider.downloads[widget.downloadId]!;
    loc = AppLocalizations.of(context)!;
    return ScrollableDialog(
      width: 550,
      height: resolveDialogHeight(size) + detailsPanelHeight,
      scrollButtonVisible: size.height <
          365 + detailsPanelHeight * 0.925 + (showSegmentBar ? 14 : 0),
      scrollViewWidth: 550,
      scrollviewHeight: 300,
      title: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            downloadStatus(),
            const Spacer(),
            InkWell(
              splashColor: Colors.transparent,
              hoverColor: Colors.white10,
              borderRadius: BorderRadius.circular(50),
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.close,
                  size: 22,
                  color: theme.widgetTheme.iconColor,
                ),
              ),
            )
          ],
        ),
      ),
      backgroundColor: theme.alertDialogTheme.backgroundColor,
      content: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${loc.file}: ${downloadProgress.downloadItem.fileName}",
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.textColor),
            ),
            Text(
              "${loc.url}: ${downloadProgress.downloadItem.downloadUrl}",
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.textColor),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                progressPercentage(),
                const Spacer(),
                completedSize(downloadProgress.downloadItem.fileSize)
              ],
            ),
            const SizedBox(height: 5),
            totalDownloadProgressIndicator(),
            if (showSegmentBar) ...[
              const SizedBox(height: 6),
              segmentProgressIndicator(),
            ],
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                speedTextContainer(),
                timeRemainingTextContainer(),
                activeConnectionsTextContainer(),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Row(
                children: [
                  connectionDetailsButton(),
                  const SizedBox(width: 10),
                  speedLimitButton(downloadProgress.downloadItem.uid),
                ],
              ),
            ),
            const SizedBox(height: 15),
            detailsPanel(downloadProgress.downloadItem.uid),
          ],
        ),
      ),
      buttons: [pauseOrResumeButton(provider)],
    );
  }

  Widget detailsPanel(String uid) {
    switch (openTab) {
      case _DetailsTab.connections:
        return connectionDetailsContainer();
      case _DetailsTab.speedLimit:
        return speedLimitContainer(uid);
      case null:
        return Container();
    }
  }

  /// The speed limit can only be changed on the fly for downloads running on the kasma engine.
  /// The status selector re-checks it when the download stops, completes or falls back to the
  /// standard engine.
  Widget speedLimitButton(String uid) {
    return Selector<DownloadRequestProvider, String>(
      selector: (_, provider) =>
          provider.downloads[widget.downloadId]!.downloadItem.status,
      builder: (context, status, child) {
        if (!KasmaDownloadEngine.isRunning(uid) || isDownloadInactive) {
          return Container();
        }
        final colors = theme.widgetTheme.showHideButtonColor;
        final open = openTab == _DetailsTab.speedLimit;
        return RoundedOutlinedButton(
          onPressed: () => toggleTab(_DetailsTab.speedLimit),
          backgroundColor: colors.backgroundColor,
          borderColor: Colors.transparent,
          hoverBackgroundColor: colors.hoverBackgroundColor,
          hoverTextColor: colors.hoverTextColor,
          textColor: colors.textColor,
          text: loc.btn_showSpeedLimit,
          icon: open ? Icons.expand_less_rounded : Icons.speed_rounded,
          iconColor: colors.iconColor,
          iconHoverColor: colors.iconColor,
        );
      },
    );
  }

  Widget speedLimitContainer(String uid) {
    return Selector<DownloadRequestProvider, String>(
      selector: (_, provider) =>
          provider.downloads[widget.downloadId]!.downloadItem.status,
      builder: (context, status, child) {
        if (!KasmaDownloadEngine.isRunning(uid) || isDownloadInactive) {
          return Container();
        }
        return Container(
          width: 550,
          height: detailsPanelHeight,
          decoration: BoxDecoration(
            color: theme.alertDialogTheme.surfaceColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SpeedLimitPanel(uid: uid),
        );
      },
    );
  }

  Widget connectionDetailsButton() {
    final showDetails = openTab == _DetailsTab.connections;
    return RoundedOutlinedButton(
      onPressed: () => toggleTab(_DetailsTab.connections),
      backgroundColor: theme.widgetTheme.showHideButtonColor.backgroundColor,
      borderColor: Colors.transparent,
      hoverBackgroundColor:
          theme.widgetTheme.showHideButtonColor.hoverBackgroundColor,
      hoverTextColor: theme.widgetTheme.showHideButtonColor.hoverTextColor,
      textColor: theme.widgetTheme.showHideButtonColor.textColor,
      text: showDetails
          ? loc.btn_hideConnectionDetails
          : loc.btn_showConnectionDetails,
      icon: showDetails ? Icons.expand_less_rounded : Icons.expand_more_rounded,
      iconColor: theme.widgetTheme.showHideButtonColor.iconColor,
      iconHoverColor: theme.widgetTheme.showHideButtonColor.iconColor,
    );
  }

  Widget connectionDetailsContainer() {
    return Visibility(
      visible: openTab == _DetailsTab.connections,
      child: Container(
        width: 550,
        height: 200,
        decoration: BoxDecoration(
          color: theme.alertDialogTheme.surfaceColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Selector<DownloadRequestProvider, List<DownloadProgressMessage>>(
          selector: (_, provider) =>
              provider.downloads[widget.downloadId]!.connectionProgresses,
          builder: (_, progresses, __) {
            return ListView.builder(
              itemCount: progresses.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Selector<DownloadRequestProvider, String>(
                      selector: (_, provider) => provider
                          .downloads[widget.downloadId]!
                          .connectionProgresses[index]
                          .connectionStatus,
                      builder: (context, transferRate, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "${loc.connection} ${(index + 1).toString()}",
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              transferRate,
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    Selector<DownloadRequestProvider, double>(
                      selector: (_, provider) => provider
                          .downloads[widget.downloadId]!
                          .connectionProgresses[index]
                          .downloadProgress,
                      builder: (context, progress, child) {
                        return SizedBox(
                          height: 10,
                          width: 550,
                          child: LinearProgressIndicator(
                            backgroundColor: theme.downloadProgressDialogTheme
                                .connectionProgressColor.backgroundColor,
                            borderRadius: BorderRadius.circular(10),
                            color: theme.downloadProgressDialogTheme
                                .connectionProgressColor.color,
                            value: progress,
                          ),
                        );
                      },
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Selector<DownloadRequestProvider, ButtonAvailability> pauseOrResumeButton(
      DownloadRequestProvider provider) {
    return Selector<DownloadRequestProvider, ButtonAvailability>(
      selector: (_, provider) =>
          provider.downloads[widget.downloadId]!.buttonAvailability,
      builder: (context, buttonEnabled, child) {
        if (isDownloadInactive) {
          return Container();
        }
        if (buttonEnabled.pauseButtonEnabled) {
          return RoundedOutlinedButton.fromButtonColor(
            mainAxisAlignment: MainAxisAlignment.center,
            contentPadding: EdgeInsetsDirectional.only(end: 6),
            theme.downloadProgressDialogTheme.pauseColor,
            onPressed: onPausePressed,
            customIcon: SizedBox(
              width: 20,
              child: Icon(
                Icons.pause_rounded,
                color: theme.downloadProgressDialogTheme.pauseColor.iconColor,
              ),
            ),
            text: loc.btn_pause,
          );
        } else if (buttonEnabled.startButtonEnabled) {
          return RoundedOutlinedButton.fromButtonColor(
            mainAxisAlignment: MainAxisAlignment.start,
            contentPadding: EdgeInsetsDirectional.only(end: 6),
            theme.downloadProgressDialogTheme.resumeColor,
            onPressed: () => provider.startDownload(widget.downloadId),
            customIcon: SizedBox(
              width: 20,
              child: Icon(
                Icons.play_arrow_rounded,
                color: theme.downloadProgressDialogTheme.resumeColor.textColor,
              ),
            ),
            text: loc.btn_resume,
          );
        } else {
          return RoundedOutlinedButton(
            borderColor: Colors.transparent,
            backgroundColor: Colors.black12,
            contentPadding: EdgeInsetsDirectional.only(end: 6),
            onPressed: null,
            icon: Icons.hourglass_bottom_rounded,
            iconColor: Colors.white70,
            iconHoverColor: Colors.white70,
            text: loc.btn_wait,
            textColor: Colors.white70,
          );
        }
      },
    );
  }

  void onPausePressed() async {
    await provider.pauseDownload(widget.downloadId);
    if (QueueScheduleHandler.runningDownloads.values
        .expand((l) => l)
        .contains(widget.downloadId)) {
      QueueScheduleHandler.stoppedDownloads.add(widget.downloadId);
    }
  }

  bool get isDownloadInactive {
    final status = provider.downloads[widget.downloadId]!.downloadItem.status;
    return status == DownloadStatus.assembleComplete ||
        status == DownloadStatus.assembling ||
        status == DownloadStatus.validatingFiles ||
        status == DownloadStatus.assembleFailed;
  }

  Widget downloadStatus() {
    return Selector<DownloadRequestProvider, String>(
      selector: (_, provider) =>
          provider.downloads[widget.downloadId]!.downloadItem.status,
      builder: (context, status, child) {
        if (status == DownloadStatus.validatingFiles) {
          status = loc.status_validatingFiles;
        } else if (status == DownloadStatus.downloading) {
          status = loc.status_downloadingFile;
        } else if (status == DownloadStatus.paused) {
          status = loc.status_paused;
        } else if (status == DownloadStatus.assembleComplete) {
          status = loc.status_complete;
        } else if (status == DownloadStatus.assembleFailed) {
          status = loc.status_downloadFailed;
        } else if (status == DownloadStatus.connecting) {
          status = loc.status_connecting;
        } else if (status == DownloadStatus.assembling) {
          status = loc.status_assemblingFile;
        } else if (status == DownloadStatus.failed) {
          status = loc.status_downloadFailed;
        } else if (status == DownloadStatus.networkError) {
          status = loc.status_networkError;
        }
        return Text(
          status,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.textColor,
            fontSize: 18,
          ),
        );
      },
    );
  }

  double resolveDialogHeight(Size size) {
    double height = showSegmentBar ? 314 : 300;
    return height;
  }

  Widget activeConnectionsTextContainer() {
    return Selector<DownloadRequestProvider, List<DownloadProgressMessage>>(
      selector: (_, provider) =>
          provider.downloads[widget.downloadId]!.connectionProgresses,
      builder: (context, connections, child) {
        final activeConnections = connections
            .where((conn) => conn.status == DownloadStatus.downloading)
            .length;
        if (isDownloadInactive) {
          return textContainer(
            title: loc.activeConnections,
            value: "",
          );
        }
        return textContainer(
          title: loc.activeConnections,
          value: "$activeConnections/${connections.length}",
        );
      },
    );
  }

  Widget timeRemainingTextContainer() {
    return Selector<DownloadRequestProvider, String>(
      selector: (_, provider) =>
          provider.downloads[widget.downloadId]!.estimatedRemaining,
      builder: (context, estimatedRemaining, child) {
        if (estimatedRemaining.contains(",")) {
          estimatedRemaining =
              estimatedRemaining.substring(0, estimatedRemaining.indexOf(","));
        }
        return textContainer(
          title: loc.timeRemaining,
          value: isDownloadInactive ? "" : estimatedRemaining,
        );
      },
    );
  }

  /// Shows a slow gauge next to the title while a speed limit is applied to the download.
  /// The limit is part of the selected value so the icon updates on the next progress update
  /// after the limit changes.
  Widget speedTextContainer() {
    return Selector<DownloadRequestProvider, (String, int)>(
      selector: (_, provider) {
        final request = provider.downloads[widget.downloadId]!;
        final uid = request.downloadItem.uid;
        final limit = KasmaDownloadEngine.isRunning(uid)
            ? KasmaDownloadEngine.speedLimitOf(uid)
            : 0;
        return (request.transferRate, limit);
      },
      builder: (context, tuple, child) {
        final (transferRate, limit) = tuple;
        final limited = limit > 0 && !isDownloadInactive;
        return textContainer(
          title: loc.speed,
          value: isDownloadInactive ? "" : transferRate,
          titleIcon: limited
              ? DefaultTooltip(
                  message: loc.speedLimit_current(SpeedUnit.format(limit)),
                  // Mirrored so the needle points at the low end of the gauge
                  child: Transform.flip(
                    flipX: true,
                    child: Icon(
                      Icons.speed_rounded,
                      size: 16,
                      color: theme.widgetTheme.iconColor,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget textContainer({
    required String title,
    required String value,
    Widget? titleIcon,
  }) {
    return Container(
      height: 80,
      width: 160,
      decoration: BoxDecoration(
        color: theme.alertDialogTheme.surfaceColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(color: theme.textColor)),
                if (titleIcon != null) ...[
                  const SizedBox(width: 6),
                  titleIcon,
                ],
              ],
            ),
            const SizedBox(height: 5),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Selector<DownloadRequestProvider, double> completedSize(int totalSize) {
    return Selector<DownloadRequestProvider, double>(
      selector: (_, provider) =>
          provider.downloads[widget.downloadId]!.downloadProgress,
      builder: (context, progress, child) {
        if (totalSize <= 0) return Container();
        final totalSizeStr = convertByteToReadableStr(totalSize);
        final completedSizeStr =
            convertByteToReadableStr((totalSize * progress).toInt());
        return Text(
          "$completedSizeStr ${loc.of_} $totalSizeStr",
          style: TextStyle(
            color: theme.textColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }

  Selector<DownloadRequestProvider, double> progressPercentage() {
    return Selector<DownloadRequestProvider, double>(
      selector: (_, provider) =>
          provider.downloads[widget.downloadId]!.downloadProgress,
      builder: (context, progress, child) => Text(
          progress == 1
              ? '${(progress * 100).toStringAsFixed(0)}%'
              : '${(progress * 100).toStringAsFixed(2)}%',
          style: TextStyle(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
          )),
    );
  }

  bool get showSegmentBar {
    final content =
        provider.downloads[widget.downloadId]?.downloadItem.m3u8Content;
    return content == null || content.isEmpty;
  }

  /// Shows how the file is split between connections and how each part is
  /// progressing.
  Widget segmentProgressIndicator() {
    return Selector<DownloadRequestProvider,
        (List<SegmentProgress>, double, int, bool)>(
      selector: (_, provider) {
        final request = provider.downloads[widget.downloadId];
        if (request == null) return (const [], 0, 0, false);
        return (
          request.segmentProgresses,
          request.downloadProgress,
          request.downloadItem.fileSize,
          request.status == DownloadStatus.assembleComplete ||
              request.downloadItem.status == DownloadStatus.assembleComplete,
        );
      },
      builder: (_, tuple, __) {
        final (segments, progress, fileSize, completed) = tuple;
        if (segments.isNotEmpty) {
          lastSegments = segments;
        }
        final dialogTheme = theme.downloadProgressDialogTheme;
        final colors = dialogTheme.totalProgressColor;
        return SegmentProgressBar(
          segments: lastSegments.isNotEmpty
              ? lastSegments
              : fallbackSegments(fileSize, progress),
          fileSize: fileSize,
          fillColor: dialogTheme.segmentProgressColor,
          backgroundColor: colors.backgroundColor,
          dividerColor: theme.alertDialogTheme.backgroundColor,
          completed: completed,
          completeColor: dialogTheme.segmentProgressColor,
        );
      },
    );
  }

  /// Used when no segment data has been received from the engine yet, e.g.
  /// for completed downloads or ones that have not been started in this
  /// session. Shows the whole file as a single segment.
  List<SegmentProgress> fallbackSegments(int fileSize, double progress) {
    if (fileSize <= 0) return [];
    if (!progress.isFinite) progress = 0;
    progress = progress.clamp(0.0, 1.0);
    return [
      SegmentProgress(
        startByte: 0,
        endByte: fileSize - 1,
        connectionNumber: 0,
        receivedBytes: (fileSize * progress).floor(),
        complete: progress >= 1,
        active: false,
      ),
    ];
  }

  Selector<DownloadRequestProvider, (String, double)>
      totalDownloadProgressIndicator() {
    return Selector<DownloadRequestProvider, (String, double)>(
      selector: (_, provider) {
        final request = provider.downloads[widget.downloadId]!;
        return (
          request.status,
          request.status == DownloadStatus.validatingFiles
              ? request.integrityValidationProgress
              : request.status == DownloadStatus.assembling
                  ? request.assembleProgress
                  : request.downloadProgress,
        );
      },
      builder: (_, tuple, __) {
        final (status, progress) = tuple;
        return SizedBox(
          height: 15,
          child: LinearProgressIndicator(
            color: status == DownloadStatus.validatingFiles
                ? theme.downloadProgressDialogTheme
                    .validatingFilesStatusProgressColor
                : status == DownloadStatus.assembling
                    ? theme.downloadProgressDialogTheme
                        .assemblingStatusProgressColor
                    : theme
                        .downloadProgressDialogTheme.totalProgressColor.color,
            backgroundColor: theme
                .downloadProgressDialogTheme.totalProgressColor.backgroundColor,
            borderRadius: BorderRadius.circular(15),
            value: progress,
          ),
        );
      },
    );
  }
}
