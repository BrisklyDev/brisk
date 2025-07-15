import 'package:brisk/provider/ffmpeg_installation_provider.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FfmpegInstallationProgressDialog extends StatefulWidget {
  FfmpegInstallationProgressDialog({super.key});

  @override
  State<FfmpegInstallationProgressDialog> createState() =>
      _FfmpegInstallationProgressDialogState();
}

class _FfmpegInstallationProgressDialogState
    extends State<FfmpegInstallationProgressDialog> {
  late DownloadProgressMessage? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    progress = Provider.of<FFmpegInstallationProvider>(context).progress;
    return AlertDialog(
      contentPadding: EdgeInsets.all(0),
      insetPadding: EdgeInsets.all(0),
      titlePadding: EdgeInsets.all(0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      backgroundColor: theme.alertDialogTheme.backgroundColor,
      title: Padding(
        padding: const EdgeInsets.all(15),
        child: Text(
          progress?.status ?? "Initializing...",
          style: TextStyle(fontSize: 18, color: theme.textColor),
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.all(15),
        child: SizedBox(
          width: 400,
          height: 5,
          child: SizedBox(
            height: 5,
            child: LinearProgressIndicator(
              backgroundColor: theme.downloadProgressDialogTheme
                  .totalProgressColor.backgroundColor,
              color: (progress?.status ?? "") == "Finalizing..."
                  ? Colors.blueAccent
                  : theme.downloadProgressDialogTheme.totalProgressColor.color,
              value: progress == null || progress!.status == "Finalizing..."
                  ? null
                  : progress?.downloadProgress ?? null,
            ),
          ),
        ),
      ),
    );
  }
}
