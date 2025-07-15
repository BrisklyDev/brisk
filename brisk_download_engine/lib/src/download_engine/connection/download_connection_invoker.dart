import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:brisk_download_engine/src/download_engine/connection/http_download_connection.dart';
import 'package:brisk_download_engine/src/download_engine/connection/m3u8_download_connection.dart';
import 'package:brisk_download_engine/src/download_engine/download_command.dart';
import 'package:brisk_download_engine/src/download_engine/message/connection_handshake_message.dart';
import 'package:brisk_download_engine/src/download_engine/message/http_download_isolate_message.dart';
import 'package:brisk_download_engine/src/download_engine/message/m3u8_download_isolate_message.dart';
import 'package:brisk_download_engine/src/download_engine/message/terminated_message.dart';
import 'package:brisk_download_engine/src/download_engine/segment/segment.dart';
import 'package:dartx/dartx.dart';
import 'package:stream_channel/isolate_channel.dart';
import 'package:stream_channel/stream_channel.dart';

class DownloadConnectionInvoker {
  static final Map<String, Map<int, HttpDownloadConnection>> _connections = {};

  static final Map<String, Pair<bool, StreamChannel>> stopCommandTrackerMap =
      {};

  static final Map<String, Set<int>> forceApplyReuseConnections = {};

  static Timer? _commandTrackerTimer;

  /// TODO : Check if it's a new connection (doesn't exist in the map) ignore it as a reference for commands
  static void _runCommandTrackerTimer() {
    if (_commandTrackerTimer != null) return;
    _commandTrackerTimer = Timer.periodic(Duration(milliseconds: 300), (_) {
      _connections.forEach((downloadUid, connections) {
        final shouldSignalStop =
            stopCommandTrackerMap[downloadUid]?.first ?? false;
        final channel = stopCommandTrackerMap[downloadUid]?.second;
        if (!shouldSignalStop) {
          return;
        }
        _connections[downloadUid]?.forEach((_, conn) {
          if (conn.connectionStatus != DownloadStatus.paused) {
            conn.pause(channel?.sink.add);
            conn.logger?.info("Invoker:: Force paused connection");
          }
        });
      });
    });
  }

  static void invokeConnection(SendPort sendPort) async {
    final channel = IsolateChannel.connectSend(sendPort);
    _runCommandTrackerTimer();
    channel.stream.cast<DownloadIsolateMessage>().listen((data) {
      final uid = data.downloadItem.uid;
      print("Received command for conn ${data.connectionNumber}");
      _connections[uid] ??= {};
      final connectionNumber = data.connectionNumber;
      HttpDownloadConnection? conn = _connections[uid]![connectionNumber!];
      _setStopCommandTracker(data, channel);
      if (conn == null) {
        conn = _buildDownloadConnection(data);
        if (data.settings.loggerEnabled) {
          conn?.initLogger();
        }
        _connections[uid]![connectionNumber] = conn!;
      }
      _executeCommand(data, channel);
    });
  }

  static HttpDownloadConnection? _buildDownloadConnection(
    DownloadIsolateMessage data,
  ) {
    if (data is HttpDownloadIsolateMessage) {
      return HttpDownloadConnection(
        downloadItem: data.downloadItem,
        segment: data.segment!,
        connectionNumber: data.connectionNumber!,
        settings: data.settings,
      );
    }
    if (data is M3u8DownloadIsolateMessage) {
      return M3U8DownloadConnection(
        downloadItem: data.downloadItem,
        m3u8segment: data.segment!,
        connectionNumber: data.connectionNumber!,
        settings: data.settings,
        segment: Segment(0, 0),
        refererHeader: data.refererHeader,
      );
    }
    return null;
  }

  static void _setStopCommandTracker(
    DownloadIsolateMessage data,
    StreamChannel channel,
  ) {
    final uid = data.downloadItem.uid;
    if (data.command == DownloadCommand.pause ||
        data.command == DownloadCommand.terminate) {
      stopCommandTrackerMap[uid] = Pair(true, channel);
      _runCommandTrackerTimer();
    } else if (data.command == DownloadCommand.start) {
      stopCommandTrackerMap[uid] = Pair(false, channel);
    }
  }

  static void _executeCommand(
    DownloadIsolateMessage data,
    IsolateChannel channel,
  ) {
    if (data is HttpDownloadIsolateMessage) {
      _executeCommandHttp(data, channel);
    }
    if (data is M3u8DownloadIsolateMessage) {
      _executeCommandM3u8(data, channel);
    }
  }

  static void _executeCommandM3u8(
    M3u8DownloadIsolateMessage data,
    IsolateChannel channel,
  ) {
    final uid = data.downloadItem.uid;
    final connectionNumber = data.connectionNumber;
    final connection =
        _connections[uid]![connectionNumber]! as M3U8DownloadConnection;
    print(
        "Executing ${data.command} conn $connectionNumber segment ${data.segment}");
    switch (data.command) {
      case DownloadCommand.startInitial:
        // connection.previousBufferEndByte = data.previouslyWrittenByteLength;
        connection.m3u8segment = data.segment!;
        connection.start(channel.sink.add);
        channel.sink.add(ConnectionHandshake.fromIsolateMessage(data));
        break;
      case DownloadCommand.start:
        connection.start(channel.sink.add);
        break;
      case DownloadCommand.pause:
        connection.pause(channel.sink.add);
        break;
      case DownloadCommand.terminate: // TODO add sink.close()
        connection.pause(channel.sink.add);
        _connections[uid]?.clear();
        break;
      case DownloadCommand.cancel:
        connection.cancel();
        _connections[uid]?.clear();
        break;
      case DownloadCommand.forceCancel:
        connection.cancel(failure: true);
        _connections[uid]?.clear();
        break;
      case DownloadCommand.resetConnection:
        connection.resetConnection();
        break;
      default:
        break;
    }
  }

  static void _executeCommandHttp(
    HttpDownloadIsolateMessage data,
    IsolateChannel channel,
  ) async {
    final uid = data.downloadItem.uid;
    final connectionNumber = data.connectionNumber;
    final connection = _connections[uid]![connectionNumber]!;
    connection.logger?.info(
      "Invoker:: Received command ${data.command} with segment ${data.segment}",
    );
    bool forcedConnectionReuse = false;
    if (shouldForceApplyReuseConnection(data)) {
      data.command = DownloadCommand.startReuseConnection;
      forceApplyReuseConnections[uid]?.remove(connectionNumber);
      forcedConnectionReuse = true;
      connection.logger?.info("Invoker:: Forcing reuseConnection...");
    }
    print("Received command ${data.command}");
    switch (data.command) {
      case DownloadCommand.startInitial:
        connection.previousBufferEndByte = data.previouslyWrittenByteLength;
        connection.start(channel.sink.add);
        channel.sink.add(ConnectionHandshake.fromIsolateMessage(data));
        break;
      case DownloadCommand.start:
        connection.start(channel.sink.add);
        break;
      case DownloadCommand.startReuseConnection:
        if (!forcedConnectionReuse) {
          connection.segment = data.segment!;
          if (connection.connectionStatus == DownloadStatus.paused) {
            connection.logger?.info(
              "Invoker:: received start_ConnectionReuse command in paused status! reset? ${connection.reset}",
            );
            forceApplyReuseConnections[uid] ??= HashSet();
            forceApplyReuseConnections[uid]!.add(connectionNumber!);
            break;
          }
        }
        connection.start(channel.sink.add, reuseConnection: true);
        channel.sink.add(
          ConnectionHandshake.fromIsolateMessage(data)..reuseConnection = true,
        );
        break;
      case DownloadCommand.pause:
        connection.pause(channel.sink.add);
        break;
      case DownloadCommand.terminate: // TODO add sink.close()
      case DownloadCommand.terminateAndEnginePanic:
        for (final conn in _connections[uid]!.values) {
          await conn.pause(null);
        }
        stopCommandTrackerMap.remove(uid);
        _connections[uid]?.clear();
        channel.sink.add(
          TerminatedMessage(
            enginePanic:
                data.command == DownloadCommand.terminateAndEnginePanic,
            downloadItem: data.downloadItem,
          ),
        );
        break;
      case DownloadCommand.cancel:
        connection.cancel();
        _connections[uid]?.clear();
        break;
      case DownloadCommand.forceCancel:
        connection.cancel(failure: true);
        _connections[uid]?.clear();
        break;
      case DownloadCommand.refreshSegment:
        connection.refreshSegment(data.segment!);
        break;
      case DownloadCommand.refreshSegmentReuseConnection:
        connection.refreshSegment(data.segment!, reuseConnection: true);
        break;
      case DownloadCommand.resetConnection:
        if (!connection.connectionRetryAllowed) {
          break;
        }
        connection.previousBufferEndByte = 0;
        connection.resetConnection();
        break;
    }
  }

  static bool shouldForceApplyReuseConnection(DownloadIsolateMessage message) {
    final uid = message.downloadItem.uid;
    return message.command == DownloadCommand.start &&
        forceApplyReuseConnections[uid] != null &&
        forceApplyReuseConnections[uid]!.contains(message.connectionNumber);
  }
}
