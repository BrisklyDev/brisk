import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/download_request_provider.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/theme/application_theme.dart';
import 'package:brisk/util/readability_util.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:brisk/widget/base/scrollable_dialog.dart';
import 'package:brisk/widget/download/queue_schedule_handler.dart';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DownloadProgressDialog extends StatefulWidget {
  final int downloadId;

  DownloadProgressDialog(this.downloadId);

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  bool showDetails = false;
  bool showDetailAvailable = true;
  late Size size;
  late ApplicationTheme theme;
  late DownloadRequestProvider provider;
  late AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<DownloadRequestProvider>(context, listen: false);
    theme = Provider.of<ThemeProvider>(context).activeTheme;
    size = MediaQuery.of(context).size;
    final downloadProgress = provider.downloads[widget.downloadId]!;
    loc = AppLocalizations.of(context)!;
    return ScrollableDialog(
      width: 550,
      height: showDetails
          ? resolveDialogHeight(size) + 200
          : resolveDialogHeight(size),
      scrollButtonVisible: size.height < (showDetails ? 550 : 365),
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
              child: RoundedOutlinedButton(
                onPressed: () {
                  setState(() {
                    showDetails = !showDetails;
                  });
                },
                backgroundColor: theme.widgetTheme.showHideButtonColor.backgroundColor,
                borderColor: Colors.transparent,
                hoverBackgroundColor:
                    theme.widgetTheme.showHideButtonColor.hoverBackgroundColor,
                hoverTextColor:
                    theme.widgetTheme.showHideButtonColor.hoverTextColor,
                textColor: theme.widgetTheme.showHideButtonColor.textColor,
                text: showDetails
                    ? loc.btn_hideConnectionDetails
                    : loc.btn_showConnectionDetails,
                icon: showDetails
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                iconColor: theme.widgetTheme.showHideButtonColor.iconColor,
                iconHoverColor: theme.widgetTheme.showHideButtonColor.iconColor,
              ),
            ),
            const SizedBox(height: 15),
            connectionDetailsContainer(),
          ],
        ),
      ),
      buttons: [pauseOrResumeButton(provider)],
    );
  }

  Widget connectionDetailsContainer() {
    return Visibility(
      visible: showDetails,
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
    double height = 300;
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

  Widget speedTextContainer() {
    return Selector<DownloadRequestProvider, String>(
      selector: (_, provider) =>
          provider.downloads[widget.downloadId]!.transferRate,
      builder: (context, transferRate, child) => textContainer(
        title: loc.speed,
        value: isDownloadInactive ? "" : transferRate,
      ),
    );
  }

  Widget textContainer({required String title, required String value}) {
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
            Text(title, style: TextStyle(color: theme.textColor)),
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
