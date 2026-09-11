import 'package:brisk/db/hive_util.dart';
import 'package:brisk/model/general_data.dart';
import 'package:brisk/widget/base/global_context.dart';
import 'package:brisk/widget/other/donation_dialog.dart';
import 'package:flutter/material.dart';

class DonationReminder {
  static const int downloadThreshold = 10;
  static const String _fieldName = 'donationReminder';

  static Future<GeneralData>? _data;
  static bool _dialogOpen = false;

  static Future<void> recordSuccessfulDownload() async {
    final data = await (_data ??= _loadData());
    final state = _readState(data);
    if (state['disabled'] == true) return;

    final successfulDownloads = (state['successfulDownloads'] as int? ?? 0) + 1;
    final nextPromptAt = state['nextPromptAt'] as int? ?? downloadThreshold;
    state['successfulDownloads'] = successfulDownloads;
    state['nextPromptAt'] = nextPromptAt;
    state['disabled'] = false;
    data.value = state;

    final shouldShow = successfulDownloads >= nextPromptAt && !_dialogOpen;
    if (shouldShow) _dialogOpen = true;

    if (!shouldShow) {
      await data.save();
      return;
    }

    try {
      await data.save();
      final context = globalContext.currentContext;
      if (context == null || !context.mounted) return;

      final action = await showDialog<DonationDialogAction>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const DonationDialog(),
      );

      final latestState = _readState(data);
      if (action == DonationDialogAction.remindLater) {
        var next =
            (latestState['nextPromptAt'] as int? ?? downloadThreshold) * 2;
        final currentCount = latestState['successfulDownloads'] as int? ?? 0;
        while (next <= currentCount) {
          next *= 2;
        }
        latestState['nextPromptAt'] = next;
      } else if (action != null) {
        latestState['disabled'] = true;
      }
      data.value = latestState;
      await data.save();
    } finally {
      _dialogOpen = false;
    }
  }

  static Future<GeneralData> _loadData() async {
    final existing = HiveUtil.instance.generalDataBox.values
        .where((data) => data.fieldName == _fieldName)
        .firstOrNull;
    if (existing != null) return existing;

    final data = GeneralData(
      fieldName: _fieldName,
      value: {
        'successfulDownloads': 0,
        'nextPromptAt': downloadThreshold,
        'disabled': false,
      },
    );
    await HiveUtil.instance.generalDataBox.add(data);
    return data;
  }

  static Map<String, dynamic> _readState(GeneralData data) {
    final value = data.value;
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }
}
