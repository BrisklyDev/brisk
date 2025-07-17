import 'dart:async';
import 'dart:collection';

import 'package:brisk/db/hive_util.dart';
import 'package:brisk/model/download_queue.dart';
import 'package:brisk/provider/download_request_provider.dart';
import 'package:brisk/provider/pluto_grid_util.dart';
import 'package:brisk/util/date_util.dart';
import 'package:brisk/util/shutdown_manager.dart';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:provider/provider.dart';

class QueueScheduleHandler {
  static Timer? downloadCheckerTimer;
  static Timer? schedulerTimer;
  static Map<DownloadQueue, List<int>> runningDownloads = {};
  static List<int> stoppedDownloads = [];
  static List<DownloadQueue> stoppedQueues = [];
  static Map<DownloadQueue, List<PlutoRow>> queueRows = {};
  static Map<DownloadQueue, bool> queues = {};

  static void schedule(
    DownloadQueue queue,
    BuildContext context, {
    required bool shutdownAfterCompletion,
    required int simultaneousDownloads,
    required DateTime? scheduledStart,
    required DateTime? scheduledEnd,
  }) async {
    final provider =
        Provider.of<DownloadRequestProvider>(context, listen: false);
    queueRows[queue] = PlutoGridUtil.plutoStateManager!.refRows.toList();
    if (scheduledStart != null) {
      scheduledStart = normalizeDate(scheduledStart);
    }
    if (scheduledEnd != null) {
      scheduledEnd = normalizeDate(scheduledEnd);
    }
    queue
      ..shutdownAfterCompletion = shutdownAfterCompletion
      ..simultaneousDownloads = simultaneousDownloads
      ..scheduledStart = scheduledStart
      ..scheduledEnd = scheduledEnd;
    await queue.save();
    queues[queue] = false;
    if (scheduledStart == null) {
      _startNow(queue, provider);
    }
    schedulerTimer ??= Timer.periodic(Duration(seconds: 10), (_) {
      queues.forEach((queue, isQueueStarted) {
        if (isQueueStarted) {
          _handleStartedQueue(queue, provider, context);
        } else {
          if (DateTime.now().isAfter(queue.scheduledStart!)) {
            _startNow(queue, provider);
          }
        }
      });
    });
  }

  static void _handleStartedQueue(
    DownloadQueue queue,
    DownloadRequestProvider provider,
    BuildContext context,
  ) async {
    if (queue.scheduledEnd != null &&
        DateTime.now().isAfter(queue.scheduledEnd!) &&
        !stoppedQueues.contains(queue)) {
      for (final id in runningDownloads[queue]!) {
        final item = await HiveUtil.instance.downloadItemsBox.get(id)!;
        DownloadEngine.terminate(item.uid);
        stoppedQueues.add(queue);
      }
      runningDownloads[queue] = [];
      if (queue.shutdownAfterCompletion) {
        ShutdownManager.scheduleShutdown();
      }
    }
  }

  static void _startNow(DownloadQueue queue, DownloadRequestProvider provider) {
    stoppedQueues.remove(queue);
    final simultaneousDownloads = queue.simultaneousDownloads;
    downloadCheckerTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      queues.forEach((queue, started) {
        if (stoppedQueues.contains(queue)) {
          return;
        }
        runningDownloads[queue] ??= [];
        List<int> toRemove = [];
        final ids = queueRows[queue]!.map((row) => row.cells['id']!.value);
        for (final id in ids) {
          final download = provider.downloads[id];
          if (download != null &&
              (download.status == DownloadStatus.assembleComplete ||
                  download.status == DownloadStatus.assembleFailed)) {
            toRemove.add(id);
          }
        }
        toRemove.forEach((id) => runningDownloads[queue]?.remove(id));
        final requestsToStart =
            simultaneousDownloads - runningDownloads[queue]!.length;
        for (int i = 0; i < requestsToStart; i++) {
          final row = fetchNextQueueRow(queue);
          if (row == null) {
            if (queue.shutdownAfterCompletion) {
              ShutdownManager.scheduleShutdown();
              downloadCheckerTimer?.cancel();
              downloadCheckerTimer = null;
              return;
            }
            continue;
          }
          final id = row.cells['id']!.value;
          provider.startDownload(id);
          queues[queue] = true;
          runningDownloads[queue]!.add(id);
        }
      });
    });
  }

  static PlutoRow? fetchNextQueueRow(DownloadQueue queue) {
    return queueRows[queue]
        ?.where(
          (row) =>
              row.cells['status']!.value != DownloadStatus.assembleComplete &&
              !stoppedDownloads.contains(row.cells['id']!.value) &&
              !runningDownloads[queue]!.contains(row.cells['id']!.value),
        )
        .toList()
        .firstOrNull;
  }
}
