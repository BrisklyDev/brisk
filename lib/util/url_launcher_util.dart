import 'dart:io';

import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/util/platform.dart';
import 'package:brisk/widget/base/error_dialog.dart';
import 'package:brisk/widget/base/global_context.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Opens [url] (http(s) or file:) with the system handler.
///
/// Inside Flatpak, url_launcher goes through GIO's OpenURI portal code, which
/// aborts the whole process in some GLib versions (gopenuriportal.c
/// call_data_free assertion) when the portal call fails, e.g. when the host
/// has no portal backend. We spawn the sandbox's xdg-open instead, so a
/// failure only affects that helper process, and tell the user why nothing
/// opened.
Future<bool> openUrl(String url) async {
  if (isFlatpak) {
    bool success;
    try {
      final result = await Process.run('xdg-open', [url]);
      success = result.exitCode == 0;
    } catch (_) {
      success = false;
    }
    if (!success) showOpenUrlFailedDialog(url);
    return success;
  }
  return launchUrlString(url);
}

void showOpenUrlFailedDialog(String url) {
  final context = globalContext.currentContext;
  if (context == null || !context.mounted) return;
  final loc = AppLocalizations.of(context)!;
  showDialog(
    context: context,
    builder: (context) => ErrorDialog(
      width: 450,
      height: 170,
      textHeight: 90,
      title: loc.openUrlFailed_title,
      description: loc.openUrlFailed_description(url),
      descriptionHint: loc.openUrlFailed_descriptionHint,
    ),
  );
}
