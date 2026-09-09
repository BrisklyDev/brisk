import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:brisk_download_engine/src/download_engine/download_type.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _argSaveDir = String.fromEnvironment('save-dir');
const _argTempDir = String.fromEnvironment('temp-dir');
const _argUrl = String.fromEnvironment('url');
const _argUrls = String.fromEnvironment('urls');
const _argUrlsFile = String.fromEnvironment('urls-file');
const _argMd5Hashes = String.fromEnvironment('md5-hashes');
const _argConnections = String.fromEnvironment('connections');
const _argM3u8Connections = String.fromEnvironment('m3u8-connections');
const _argRetryTimeoutMillis = String.fromEnvironment('retry-timeout-ms');
const _argMaxRetries = String.fromEnvironment('max-retries');
const _argProgressLogMillis = String.fromEnvironment('progress-log-ms');
const _argMaxRuns = String.fromEnvironment('max-runs');
const _argPauseResume = bool.fromEnvironment('pause-resume');
const _pauseResumeProbeCycles = 2;
const _pauseResumeProbeMinProgress = 0.05;
const _pauseResumeProbeMaxProgress = 0.95;

void main() {
  test(
    'stress downloads configured URLs in a cycle',
    () async {
      final config = StressConfig.fromCommandLine(Platform.environment);
      if (config == null) {
        markTestSkipped(
          'Pass --dart-define=save-dir=..., --dart-define=temp-dir=..., '
          'and either --dart-define=urls=... or --dart-define=urls-file=... '
          'to run this stress test.',
        );
        return;
      }

      await runStressDownloadCycle(config);
    },
    timeout: Timeout.none,
  );

  group('connection limit guard', () {
    test('allows connection numbers inside the configured limit', () {
      final message = _progressWithConnectionNumbers([0, 1, 2, 3]);

      expect(_connectionLimitFailure(message, 4), isNull);
    });

    test('detects too many unique connections', () {
      final message = _progressWithConnectionNumbers([0, 1, 2, 3]);

      expect(
        _connectionLimitFailure(message, 3),
        contains('exceeds configured limit 3'),
      );
    });

    test('detects connection numbers outside the configured range', () {
      final message = _progressWithConnectionNumbers([0, 1, 2, 8]);

      expect(
        _connectionLimitFailure(message, 8),
        contains('outside allowed range 0-7'),
      );
    });
  });

  group('md5 validation', () {
    test('parses md5 hashes by URL index', () {
      const firstHash = 'd41d8cd98f00b204e9800998ecf8427e';
      const secondHash = '900150983cd24fb0d6963f7d28e17f72';

      final config = StressConfig.fromCommandLine(
        _stressEnvironment(
          urls: 'https://example.com/one,https://example.com/two',
          md5Hashes: '$firstHash,$secondHash',
        ),
      );

      expect(config!.md5Hashes, [firstHash, secondHash]);
    });

    test('rejects md5 hash counts that do not match URL count', () {
      expect(
        () => StressConfig.fromCommandLine(
          _stressEnvironment(
            urls: 'https://example.com/one,https://example.com/two',
            md5Hashes: 'd41d8cd98f00b204e9800998ecf8427e',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid md5 hashes', () {
      expect(
        () => StressConfig.fromCommandLine(
          _stressEnvironment(
            urls: 'https://example.com/one',
            md5Hashes: 'not-a-md5',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('calculates md5 hashes for assembled files', () async {
      final tempDir = Directory.systemTemp.createTempSync('brisk_md5_test_');
      try {
        final file = File(p.join(tempDir.path, 'file.txt'))
          ..writeAsStringSync('abc');

        expect(
          await _calculateFileMd5(file.path),
          '900150983cd24fb0d6963f7d28e17f72',
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('artifact cleanup', () {
    test('deletes successful downloads when md5 is not configured', () {
      expect(_shouldDeleteDownloadArtifacts(_downloadRunResult()), isTrue);
    });

    test('deletes successful downloads only after md5 matches', () {
      const expectedMd5 = '900150983cd24fb0d6963f7d28e17f72';

      expect(
        _shouldDeleteDownloadArtifacts(
          _downloadRunResult(
            expectedMd5: expectedMd5,
            actualMd5: expectedMd5,
          ),
        ),
        isTrue,
      );
      expect(
        _shouldDeleteDownloadArtifacts(
          _downloadRunResult(
            expectedMd5: expectedMd5,
            actualMd5: 'd41d8cd98f00b204e9800998ecf8427e',
          ),
        ),
        isFalse,
      );
      expect(
        _shouldDeleteDownloadArtifacts(
          _downloadRunResult(expectedMd5: expectedMd5),
        ),
        isFalse,
      );
    });

    test('keeps failed downloads even when md5 is not configured', () {
      expect(
        _shouldDeleteDownloadArtifacts(_downloadRunResult(success: false)),
        isFalse,
      );
    });
  });

  group('stress test logging', () {
    test('mirrors stress failure messages to shared and run log files', () {
      final tempDir =
          Directory.systemTemp.createTempSync('brisk_stress_log_test_');
      try {
        final logger = _StressTestLogger(tempDir, mirrorToConsole: false);
        final runLogFilePath = p.join(tempDir.path, 'Logs', 'run_logs.log');

        logger.info('Stress download runner started');
        logger.error(
          'Connection limit exceeded.\nReason: observed 9 connections',
          logFilePath: runLogFilePath,
        );

        final stressLog = File(logger.logFilePath).readAsStringSync();
        final runLog = File(runLogFilePath).readAsStringSync();

        expect(stressLog, contains('INFO:: Stress download runner started'));
        expect(stressLog, contains('ERROR:: Connection limit exceeded.'));
        expect(stressLog, contains('ERROR:: Reason: observed 9 connections'));
        expect(runLog, contains('ERROR:: Connection limit exceeded.'));
        expect(runLog, contains('ERROR:: Reason: observed 9 connections'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('detects engine panic text in logs with malformed utf8 bytes', () {
      final tempDir =
          Directory.systemTemp.createTempSync('brisk_stress_log_test_');
      try {
        final logFile = File(p.join(tempDir.path, 'Logs', 'run_logs.log'));
        logFile.parent.createSync(recursive: true);
        logFile.writeAsBytesSync([
          0xff,
          0xfe,
          ...'download progress exceeded 1'.codeUnits,
        ]);

        expect(_enginePanicked(logFile.path), isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('pause/resume probe', () {
    test('is disabled by default in stress config', () {
      final config = StressConfig.fromCommandLine(
        _stressEnvironment(urls: 'https://example.com/file.bin'),
      );

      expect(config!.pauseResumeProbeEnabled, isFalse);
    });

    test('can be enabled with stress environment flag', () {
      final config = StressConfig.fromCommandLine(
        _stressEnvironment(
          urls: 'https://example.com/file.bin',
          pauseResume: 'true',
        ),
      );

      expect(config!.pauseResumeProbeEnabled, isTrue);
    });

    test('tries two pause/resume cycles at randomized targets', () {
      final commands = <String>[];
      final probe = _PauseResumeProbe(
        uid: 'download-1',
        runNumber: 1,
        enabled: true,
        pauseTargets: [0.2, 0.4],
        pause: (uid) => commands.add('pause:$uid'),
        resume: (uid) => commands.add('resume:$uid'),
        log: (_) {},
      );

      probe.handleProgress(
        _progressForPauseResume(
          progress: 0.15,
          pauseButtonEnabled: true,
        ),
      );
      expect(commands, isEmpty);

      probe.handleProgress(
        _progressForPauseResume(
          progress: 0.25,
          pauseButtonEnabled: false,
        ),
      );
      expect(commands, isEmpty);

      probe.handleProgress(
        _progressForPauseResume(
          progress: 0.25,
          pauseButtonEnabled: true,
        ),
      );
      expect(commands, ['pause:download-1']);

      probe.handleButtonAvailability(
        _buttonAvailability(
          pauseButtonEnabled: false,
          startButtonEnabled: false,
        ),
      );
      expect(commands, ['pause:download-1']);

      probe.handleButtonAvailability(
        _buttonAvailability(
          pauseButtonEnabled: false,
          startButtonEnabled: true,
        ),
      );
      expect(commands, ['pause:download-1', 'resume:download-1']);

      probe.handleProgress(
        _progressForPauseResume(
          progress: 0.35,
          pauseButtonEnabled: true,
        ),
      );
      expect(commands, ['pause:download-1', 'resume:download-1']);

      probe.handleProgress(
        _progressForPauseResume(
          progress: 0.45,
          pauseButtonEnabled: true,
        ),
      );
      expect(commands, [
        'pause:download-1',
        'resume:download-1',
        'pause:download-1',
      ]);

      probe.handleButtonAvailability(
        _buttonAvailability(
          pauseButtonEnabled: false,
          startButtonEnabled: true,
        ),
      );
      expect(commands, [
        'pause:download-1',
        'resume:download-1',
        'pause:download-1',
        'resume:download-1',
      ]);

      probe.handleProgress(
        _progressForPauseResume(
          progress: 0.75,
          pauseButtonEnabled: true,
        ),
      );
      expect(commands, [
        'pause:download-1',
        'resume:download-1',
        'pause:download-1',
        'resume:download-1',
      ]);
    });

    test('does not pause downloads that do not support pause', () {
      final commands = <String>[];
      final probe = _PauseResumeProbe(
        uid: 'download-1',
        runNumber: 1,
        enabled: false,
        pauseTargets: [0.2, 0.4],
        pause: (uid) => commands.add('pause:$uid'),
        resume: (uid) => commands.add('resume:$uid'),
        log: (_) {},
      );

      probe.handleProgress(
        _progressForPauseResume(
          progress: 0.25,
          pauseButtonEnabled: true,
          startButtonEnabled: true,
        ),
      );

      expect(commands, isEmpty);
    });
  });
}

Future<void> runStressDownloadCycle(StressConfig config) async {
  config.saveDir.createSync(recursive: true);
  config.tempDir.createSync(recursive: true);
  final logger = _StressTestLogger(config.tempDir)..reset();

  logger.info('Stress download runner started');
  logger.info('URLs: ${config.urls.length}');
  logger.info(
    'MD5 validation: ${config.md5Hashes == null ? 'disabled' : 'enabled'}',
  );
  logger.info('Save dir: ${config.saveDir.absolute.path}');
  logger.info('Temp dir: ${config.tempDir.absolute.path}');
  logger.info('Connections: ${config.connections}');
  logger.info(
    'Max runs: ${config.maxRuns == 0 ? 'unlimited' : config.maxRuns}',
  );
  logger.info('Engine logs: ${p.join(config.tempDir.path, 'Logs')}');
  logger.info('Stress test log: ${logger.logFilePath}');
  logger.info('');

  var urlIndex = 0;
  var runNumber = 0;
  while (config.maxRuns == 0 || runNumber < config.maxRuns) {
    final url = config.urls[urlIndex];
    final expectedMd5 = config.md5Hashes?[urlIndex];
    String? runLogFilePath;
    runNumber++;
    logger.info(
      '[run $runNumber] Starting URL ${urlIndex + 1}/${config.urls.length}: $url',
    );

    try {
      final result = await _downloadOnce(
        url: url,
        expectedMd5: expectedMd5,
        runNumber: runNumber,
        config: config,
        logger: logger,
        onRunLogFilePath: (logFilePath) => runLogFilePath = logFilePath,
      );
      if (result.enginePanicked) {
        throw StressEnginePanicException(result);
      }
      if (result.connectionLimitExceeded) {
        throw StressConnectionLimitException(result);
      }
      if (result.md5Mismatch) {
        throw StressMd5MismatchException(result);
      }
      if (_shouldDeleteDownloadArtifacts(result)) {
        logger.info(
          '[run $runNumber] Success. Deleting downloaded file, temp folder, '
          'and log file.',
          logFilePath: result.logFilePath,
        );
        _deleteDownloadArtifacts(result);
        logger.info('[run $runNumber] Deleted successful download artifacts.');
      } else if (result.success) {
        logger.info(
          '[run $runNumber] Completed but MD5 was not verified. '
          'Keeping files for inspection.',
          logFilePath: result.logFilePath,
        );
      } else {
        logger.info(
          '[run $runNumber] Failed with status "${result.status}". Keeping files for inspection.',
          logFilePath: result.logFilePath,
        );
      }
    } catch (error, stackTrace) {
      if (error is StressEnginePanicException) {
        logger.error(error.message, logFilePath: error.result.logFilePath);
        rethrow;
      }
      if (error is StressConnectionLimitException) {
        logger.error(error.message, logFilePath: error.result.logFilePath);
        rethrow;
      }
      if (error is StressMd5MismatchException) {
        logger.error(error.message, logFilePath: error.result.logFilePath);
        rethrow;
      }
      logger.error(
        '[run $runNumber] Failed before completion: $error',
        logFilePath: runLogFilePath,
      );
      logger.error(stackTrace.toString(), logFilePath: runLogFilePath);
    }

    urlIndex = (urlIndex + 1) % config.urls.length;
  }

  logger.info('Stress download runner finished after $runNumber runs.');
}

Future<DownloadRunResult> _downloadOnce({
  required String url,
  required String? expectedMd5,
  required int runNumber,
  required StressConfig config,
  required _StressTestLogger logger,
  required void Function(String logFilePath) onRunLogFilePath,
}) async {
  final item = await DownloadEngine.buildDownloadItem(url);
  final fileName = _stressFileName(runNumber, item.fileName);
  item
    ..fileName = fileName
    ..filePath = p.join(config.saveDir.path, fileName)
    ..startDate = DateTime.now();

  _deleteIfExists(item.filePath);
  final logFilePath = _downloadLogFilePath(config, item.uid);
  onRunLogFilePath(logFilePath);
  logger.info('[run $runNumber] URL: $url', logFilePath: logFilePath);
  logger.info(
    '[run $runNumber] Download UID: ${item.uid}',
    logFilePath: logFilePath,
  );
  logger.info(
    '[run $runNumber] Output file: ${item.filePath}',
    logFilePath: logFilePath,
  );
  logger.info(
    '[run $runNumber] Engine log file: $logFilePath',
    logFilePath: logFilePath,
  );

  final completer = Completer<DownloadRunResult>();
  final connectionLimit = item.supportsPause ? config.connections : 1;
  final normalizedExpectedMd5 =
      expectedMd5 == null ? null : _normalizeMd5Hash(expectedMd5);
  final pauseResumeProbe = _PauseResumeProbe(
    uid: item.uid,
    runNumber: runNumber,
    enabled: config.pauseResumeProbeEnabled && item.supportsPause,
    log: (message) => logger.info(message, logFilePath: logFilePath),
  );
  var lastStatus = '';
  var lastProgressLogMillis = 0;
  var terminatingForConnectionLimit = false;
  var completingAfterAssemble = false;

  final settings = DownloadSettings(
    baseSaveDir: config.saveDir,
    baseTempDir: config.tempDir,
    totalConnections: item.supportsPause ? config.connections : 1,
    totalM3u8Connections: config.m3u8Connections,
    loggerEnabled: true,
    connectionRetryTimeoutMillis: config.connectionRetryTimeoutMillis,
    maxConnectionRetryCount: config.maxConnectionRetryCount,
  );

  void complete(
    bool success,
    String status, {
    bool connectionLimitExceeded = false,
    bool md5Mismatch = false,
    String? actualMd5,
    String? failureMessage,
  }) {
    if (completer.isCompleted) return;
    final tempDirectoryPath = _downloadTempDirectoryPath(config, item.uid);
    final enginePanicked = _enginePanicked(logFilePath);
    _disposeDownloadState(item.uid);
    completer.complete(
      DownloadRunResult(
        success: success,
        status: status,
        filePath: item.filePath,
        tempDirectoryPath: tempDirectoryPath,
        logFilePath: logFilePath,
        url: url,
        enginePanicked: enginePanicked,
        connectionLimitExceeded: connectionLimitExceeded,
        md5Mismatch: md5Mismatch,
        expectedMd5: normalizedExpectedMd5,
        actualMd5: actualMd5,
        failureMessage: failureMessage,
      ),
    );
  }

  Future<void> completeAfterHashValidation(String status) async {
    if (completingAfterAssemble || completer.isCompleted) return;
    completingAfterAssemble = true;
    if (normalizedExpectedMd5 == null) {
      complete(true, status);
      return;
    }

    String actualMd5;
    try {
      actualMd5 = await _calculateFileMd5(item.filePath);
    } catch (error, stackTrace) {
      logger.error(
        '[run $runNumber] Failed to calculate MD5: $error',
        logFilePath: logFilePath,
      );
      logger.error(stackTrace.toString(), logFilePath: logFilePath);
      complete(
        false,
        'md5ValidationFailed',
        md5Mismatch: true,
        failureMessage: 'Failed to calculate MD5: $error',
      );
      return;
    }

    if (actualMd5 != normalizedExpectedMd5) {
      complete(
        false,
        'md5Mismatch',
        md5Mismatch: true,
        actualMd5: actualMd5,
        failureMessage:
            'Expected MD5 $normalizedExpectedMd5 but got $actualMd5',
      );
      return;
    }
    logger.info(
      '[run $runNumber] MD5 matched: $actualMd5',
      logFilePath: logFilePath,
    );
    complete(true, status, actualMd5: actualMd5);
  }

  void failForConnectionLimit(String failureMessage) {
    if (terminatingForConnectionLimit || completer.isCompleted) return;
    terminatingForConnectionLimit = true;
    logger.error('[run $runNumber] $failureMessage', logFilePath: logFilePath);
    unawaited(
      DownloadEngine.terminate(item.uid)
          .timeout(const Duration(seconds: 5))
          .catchError((_) {})
          .whenComplete(
            () => complete(
              false,
              'connectionLimitExceeded',
              connectionLimitExceeded: true,
              failureMessage: failureMessage,
            ),
          ),
    );
  }

  DownloadEngine.start(
    item,
    settings,
    DownloadType.http,
    onButtonAvailability: pauseResumeProbe.handleButtonAvailability,
    onDownloadProgress: (message) {
      final connectionLimitFailure = _connectionLimitFailure(
        message,
        connectionLimit,
      );
      if (connectionLimitFailure != null) {
        failForConnectionLimit(connectionLimitFailure);
        return;
      }

      pauseResumeProbe.handleProgress(message);

      if (message.status != lastStatus) {
        lastStatus = message.status;
        logger.info(
          '[run $runNumber] Status: ${message.status}',
          logFilePath: logFilePath,
        );
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastProgressLogMillis >= config.progressLogIntervalMillis) {
        lastProgressLogMillis = now;
        final progress = (message.totalDownloadProgress * 100).clamp(0, 100);
        logger.info(
          '[run $runNumber] ${progress.toStringAsFixed(2)}% '
                  '${message.transferRate} ${message.estimatedRemaining}'
              .trimRight(),
          logFilePath: logFilePath,
        );
      }

      switch (message.status) {
        case DownloadStatus.assembleComplete:
          unawaited(completeAfterHashValidation(message.status));
          break;
        case DownloadStatus.assembleFailed:
        case DownloadStatus.failed:
        case DownloadStatus.canceled:
        case DownloadStatus.networkError:
          complete(false, message.status);
          break;
      }
    },
  );

  return completer.future;
}

class _StressTestLogger {
  final Directory tempDir;
  final bool mirrorToConsole;

  _StressTestLogger(this.tempDir, {this.mirrorToConsole = true});

  String get logFilePath =>
      p.join(tempDir.path, 'Logs', 'stress_download_engine_test.log');

  void reset() {
    _deleteFileIfExists(logFilePath);
  }

  void info(String message, {String? logFilePath}) {
    if (mirrorToConsole) {
      stdout.writeln(message);
    }
    _append('INFO', message, logFilePath);
  }

  void error(String message, {String? logFilePath}) {
    if (mirrorToConsole) {
      stderr.writeln(message);
    }
    _append('ERROR', message, logFilePath);
  }

  void _append(String level, String message, String? runLogFilePath) {
    final entry = _formatEntry(level, message);
    _appendToFile(logFilePath, entry);
    if (runLogFilePath != null &&
        p.normalize(runLogFilePath) != p.normalize(logFilePath)) {
      _appendToFile(runLogFilePath, entry);
    }
  }

  String _formatEntry(String level, String message) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();
    final lines = message.isEmpty ? const [''] : message.split('\n');
    for (final line in lines) {
      buffer.writeln('@$timestamp $level:: $line');
    }
    return buffer.toString();
  }

  void _appendToFile(String filePath, String entry) {
    final file = File(filePath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(entry, mode: FileMode.writeOnlyAppend, flush: true);
  }
}

void _disposeDownloadState(String uid) {
  try {
    DownloadEngine.engineChannels.remove(uid)?.sink.close();
  } catch (_) {}
  DownloadEngine.engineIsolates.remove(uid)?.kill(priority: Isolate.immediate);
  DownloadEngine.downloadItems.remove(uid);
  DownloadEngine.buttonAvailabilities.remove(uid);
  DownloadEngine.engineTerminationCompleter.remove(uid);
}

class _PauseResumeProbe {
  final String uid;
  final int runNumber;
  final bool enabled;
  final void Function(String uid) pause;
  final void Function(String uid) resume;
  final void Function(String message) _log;
  final List<double> _pauseTargets;

  int _pauseRequests = 0;
  int _resumeRequests = 0;
  double _progress = 0;
  String _status = '';
  ButtonAvailability _buttonAvailability =
      const ButtonAvailability(false, false);

  _PauseResumeProbe({
    required this.uid,
    required this.runNumber,
    required this.enabled,
    this.pause = DownloadEngine.pause,
    this.resume = DownloadEngine.resume,
    int pauseCycles = _pauseResumeProbeCycles,
    Random? random,
    List<double>? pauseTargets,
    void Function(String message)? log,
  })  : _pauseTargets = List.unmodifiable(
          pauseTargets ??
              _randomPauseTargets(
                pauseCycles,
                random ?? Random(),
              ),
        ),
        _log = log ?? stdout.writeln;

  void handleProgress(DownloadProgressMessage message) {
    _progress = message.totalDownloadProgress;
    _status = message.status;
    _buttonAvailability = message.buttonAvailability;
    _maybePauseOrResume();
  }

  void handleButtonAvailability(ButtonAvailabilityMessage message) {
    _buttonAvailability = ButtonAvailability(
      message.pauseButtonEnabled,
      message.startButtonEnabled,
    );
    _maybePauseOrResume();
  }

  void _maybePauseOrResume() {
    if (!enabled || _isTerminalStatus) {
      return;
    }
    if (_canPause) {
      final pauseNumber = _pauseRequests + 1;
      final targetPercent = (_pauseTargets[_pauseRequests] * 100)
          .clamp(0, 100)
          .toStringAsFixed(0);
      _pauseRequests++;
      _log(
        '[run $runNumber] Pausing for pause/resume probe '
        '$pauseNumber/${_pauseTargets.length} near $targetPercent%.',
      );
      pause(uid);
      return;
    }
    if (_canResume) {
      _resumeRequests++;
      _log(
        '[run $runNumber] Resuming after pause/resume probe '
        '$_resumeRequests/${_pauseTargets.length}.',
      );
      resume(uid);
    }
  }

  bool get _canPause =>
      !_awaitingResume &&
      _pauseRequests < _pauseTargets.length &&
      _status == DownloadStatus.downloading &&
      _progress >= _pauseTargets[_pauseRequests] &&
      _progress < _pauseResumeProbeMaxProgress &&
      _buttonAvailability.pauseButtonEnabled;

  bool get _canResume =>
      _awaitingResume && _buttonAvailability.startButtonEnabled;

  bool get _awaitingResume => _pauseRequests > _resumeRequests;

  bool get _isTerminalStatus =>
      _progress >= 1 ||
      _status == DownloadStatus.assembleComplete ||
      _status == DownloadStatus.assembleFailed ||
      _status == DownloadStatus.failed ||
      _status == DownloadStatus.canceled ||
      _status == DownloadStatus.networkError;

  static List<double> _randomPauseTargets(int cycles, Random random) {
    if (cycles <= 0) {
      return const [];
    }
    final range = _pauseResumeProbeMaxProgress - _pauseResumeProbeMinProgress;
    return List.generate(cycles, (index) {
      final windowStart = _pauseResumeProbeMinProgress + range * index / cycles;
      final windowEnd =
          _pauseResumeProbeMinProgress + range * (index + 1) / cycles;
      return windowStart + random.nextDouble() * (windowEnd - windowStart);
    });
  }
}

void _deleteDownloadArtifacts(DownloadRunResult result) {
  _deleteFileIfExists(result.filePath);
  _deleteDirectoryIfExists(result.tempDirectoryPath);
  _deleteFileIfExists(result.logFilePath);
}

bool _shouldDeleteDownloadArtifacts(DownloadRunResult result) {
  if (!result.success) {
    return false;
  }
  if (result.expectedMd5 == null) {
    return true;
  }
  return result.actualMd5 == result.expectedMd5;
}

void _deleteIfExists(String filePath) {
  _deleteFileIfExists(filePath);
}

void _deleteFileIfExists(String filePath) {
  final file = File(filePath);
  if (file.existsSync()) {
    file.deleteSync();
  }
}

void _deleteDirectoryIfExists(String directoryPath) {
  final directory = Directory(directoryPath);
  if (directory.existsSync()) {
    directory.deleteSync(recursive: true);
  }
}

Future<String> _calculateFileMd5(String filePath) async {
  final digest = await crypto.md5.bind(File(filePath).openRead()).first;
  return digest.toString();
}

String _normalizeMd5Hash(String hash) => hash.trim().toLowerCase();

bool _isMd5Hash(String hash) => RegExp(r'^[0-9a-f]{32}$').hasMatch(hash);

bool _enginePanicked(String logFilePath) {
  final logFile = File(logFilePath);
  if (!logFile.existsSync()) {
    return false;
  }
  final log = String.fromCharCodes(logFile.readAsBytesSync()).toLowerCase();
  return log.contains('engine panicked') ||
      log.contains('sending engine panic') ||
      log.contains('download progress exceeded 1');
}

String? _connectionLimitFailure(
  DownloadProgressMessage message,
  int connectionLimit,
) {
  if (connectionLimit <= 0 || message.connectionProgresses.isEmpty) {
    return null;
  }
  final connectionNumbers = message.connectionProgresses
      .map((progress) => progress.connectionNumber)
      .toSet()
      .toList()
    ..sort();
  if (connectionNumbers.length > connectionLimit) {
    return 'Observed ${connectionNumbers.length} connections, which exceeds '
        'configured limit $connectionLimit. Connections: $connectionNumbers';
  }
  for (final connectionNumber in connectionNumbers) {
    if (connectionNumber < 0 || connectionNumber >= connectionLimit) {
      return 'Observed connection $connectionNumber outside allowed range '
          '0-${connectionLimit - 1}. Connections: $connectionNumbers';
    }
  }
  return null;
}

DownloadProgressMessage _progressWithConnectionNumbers(
  List<int> connectionNumbers,
) {
  final item = _testDownloadItem();
  final message = DownloadProgressMessage(downloadItem: item);
  message.connectionProgresses = connectionNumbers
      .map(
        (connectionNumber) => DownloadProgressMessage(
          downloadItem: item,
          connectionNumber: connectionNumber,
        ),
      )
      .toList();
  return message;
}

DownloadProgressMessage _progressForPauseResume({
  required double progress,
  String status = DownloadStatus.downloading,
  bool pauseButtonEnabled = false,
  bool startButtonEnabled = false,
}) {
  return DownloadProgressMessage(
    downloadItem: _testDownloadItem(),
    status: status,
    totalDownloadProgress: progress,
    buttonAvailability: ButtonAvailability(
      pauseButtonEnabled,
      startButtonEnabled,
    ),
  );
}

ButtonAvailabilityMessage _buttonAvailability({
  required bool pauseButtonEnabled,
  required bool startButtonEnabled,
}) {
  return ButtonAvailabilityMessage(
    downloadItem: _testDownloadItem(),
    pauseButtonEnabled: pauseButtonEnabled,
    startButtonEnabled: startButtonEnabled,
  );
}

DownloadItemModel _testDownloadItem() {
  return DownloadItemModel(
    fileName: 'file.bin',
    downloadUrl: 'https://example.com/file.bin',
    progress: 0,
    fileSize: 1,
  );
}

DownloadRunResult _downloadRunResult({
  bool success = true,
  String? expectedMd5,
  String? actualMd5,
}) {
  return DownloadRunResult(
    success: success,
    status: success ? DownloadStatus.assembleComplete : DownloadStatus.failed,
    filePath: 'file.bin',
    tempDirectoryPath: 'temp',
    logFilePath: 'log',
    url: 'https://example.com/file.bin',
    enginePanicked: false,
    expectedMd5: expectedMd5,
    actualMd5: actualMd5,
  );
}

String _downloadTempDirectoryPath(StressConfig config, String uid) {
  return p.join(config.tempDir.path, uid);
}

String _downloadLogFilePath(StressConfig config, String uid) {
  return p.join(config.tempDir.path, 'Logs', '${uid}_logs.log');
}

String _stressFileName(int runNumber, String rawFileName) {
  final fileName = rawFileName.trim().isEmpty ? 'download.bin' : rawFileName;
  final sanitized = fileName.replaceAll(RegExp(r'[<>:"/\\|?*\n\r]'), '_');
  return 'stress_${runNumber}_$sanitized';
}

Map<String, String> _stressEnvironment({
  required String urls,
  String? md5Hashes,
  String? pauseResume,
}) {
  return {
    'BRISK_STRESS_SAVE_DIR': p.join(Directory.systemTemp.path, 'brisk-save'),
    'BRISK_STRESS_TEMP_DIR': p.join(Directory.systemTemp.path, 'brisk-temp'),
    'BRISK_STRESS_URLS': urls,
    if (md5Hashes != null) 'BRISK_STRESS_MD5_HASHES': md5Hashes,
    if (pauseResume != null) 'BRISK_STRESS_PAUSE_RESUME': pauseResume,
  };
}

class DownloadRunResult {
  final bool success;
  final String status;
  final String filePath;
  final String tempDirectoryPath;
  final String logFilePath;
  final String url;
  final bool enginePanicked;
  final bool connectionLimitExceeded;
  final bool md5Mismatch;
  final String? expectedMd5;
  final String? actualMd5;
  final String? failureMessage;

  DownloadRunResult({
    required this.success,
    required this.status,
    required this.filePath,
    required this.tempDirectoryPath,
    required this.logFilePath,
    required this.url,
    required this.enginePanicked,
    this.connectionLimitExceeded = false,
    this.md5Mismatch = false,
    this.expectedMd5,
    this.actualMd5,
    this.failureMessage,
  });
}

class StressEnginePanicException implements Exception {
  final DownloadRunResult result;

  StressEnginePanicException(this.result);

  String get message => 'Engine panic detected after completed download. '
      'Stopping stress test for investigation.\n'
      'URL: ${result.url}\n'
      'Downloaded file: ${result.filePath}\n'
      'Temp folder: ${result.tempDirectoryPath}\n'
      'Log file: ${result.logFilePath}';

  @override
  String toString() => message;
}

class StressConnectionLimitException implements Exception {
  final DownloadRunResult result;

  StressConnectionLimitException(this.result);

  String get message => 'Connection limit exceeded. '
      'Stopping stress test for investigation.\n'
      'Reason: ${result.failureMessage}\n'
      'URL: ${result.url}\n'
      'Downloaded file: ${result.filePath}\n'
      'Temp folder: ${result.tempDirectoryPath}\n'
      'Log file: ${result.logFilePath}';

  @override
  String toString() => message;
}

class StressMd5MismatchException implements Exception {
  final DownloadRunResult result;

  StressMd5MismatchException(this.result);

  String get message => 'MD5 validation failed. '
      'Stopping stress test for investigation.\n'
      'Reason: ${result.failureMessage}\n'
      'Expected MD5: ${result.expectedMd5}\n'
      'Actual MD5: ${result.actualMd5 ?? 'unavailable'}\n'
      'URL: ${result.url}\n'
      'Downloaded file: ${result.filePath}\n'
      'Temp folder: ${result.tempDirectoryPath}\n'
      'Log file: ${result.logFilePath}';

  @override
  String toString() => message;
}

class StressConfig {
  final Directory saveDir;
  final Directory tempDir;
  final List<String> urls;
  final List<String>? md5Hashes;
  final int connections;
  final int m3u8Connections;
  final int connectionRetryTimeoutMillis;
  final int maxConnectionRetryCount;
  final int progressLogIntervalMillis;
  final int maxRuns;
  final bool pauseResumeProbeEnabled;

  StressConfig({
    required this.saveDir,
    required this.tempDir,
    required this.urls,
    this.md5Hashes,
    required this.connections,
    required this.m3u8Connections,
    required this.connectionRetryTimeoutMillis,
    required this.maxConnectionRetryCount,
    required this.progressLogIntervalMillis,
    required this.maxRuns,
    required this.pauseResumeProbeEnabled,
  });

  static StressConfig? fromCommandLine(Map<String, String> environment) {
    final saveDir = _firstNonEmpty(
      _argSaveDir,
      environment['BRISK_STRESS_SAVE_DIR'],
    );
    final tempDir = _firstNonEmpty(
      _argTempDir,
      environment['BRISK_STRESS_TEMP_DIR'],
    );
    final urls = _readUrls(environment);
    if (saveDir == null || tempDir == null || urls.isEmpty) {
      return null;
    }
    final md5Hashes = _readMd5Hashes(environment, urls.length);

    return StressConfig(
      saveDir: Directory(saveDir),
      tempDir: Directory(tempDir),
      urls: urls,
      md5Hashes: md5Hashes,
      connections: _parsePositiveInt(
        _firstNonEmpty(
            _argConnections, environment['BRISK_STRESS_CONNECTIONS']),
        defaultValue: 8,
      ),
      m3u8Connections: _parsePositiveInt(
        _firstNonEmpty(
          _argM3u8Connections,
          environment['BRISK_STRESS_M3U8_CONNECTIONS'],
        ),
        defaultValue: 8,
      ),
      connectionRetryTimeoutMillis: _parsePositiveInt(
        _firstNonEmpty(
          _argRetryTimeoutMillis,
          environment['BRISK_STRESS_RETRY_TIMEOUT_MS'],
        ),
        defaultValue: 10000,
      ),
      maxConnectionRetryCount: int.tryParse(
            _firstNonEmpty(
                    _argMaxRetries, environment['BRISK_STRESS_MAX_RETRIES']) ??
                '',
          ) ??
          -1,
      progressLogIntervalMillis: _parsePositiveInt(
        _firstNonEmpty(
          _argProgressLogMillis,
          environment['BRISK_STRESS_PROGRESS_LOG_MS'],
        ),
        defaultValue: 1000,
      ),
      maxRuns: _parseNonNegativeInt(
        _firstNonEmpty(_argMaxRuns, environment['BRISK_STRESS_MAX_RUNS']),
        defaultValue: 0,
      ),
      pauseResumeProbeEnabled: _argPauseResume ||
          _parseBool(environment['BRISK_STRESS_PAUSE_RESUME']),
    );
  }

  static List<String>? _readMd5Hashes(
    Map<String, String> environment,
    int urlCount,
  ) {
    final rawHashes = _firstNonEmpty(
      _argMd5Hashes,
      environment['BRISK_STRESS_MD5_HASHES'],
    );
    if (rawHashes == null) {
      return null;
    }

    final hashes = rawHashes
        .split(',')
        .map(_normalizeMd5Hash)
        .where((hash) => hash.isNotEmpty)
        .toList();
    if (hashes.isEmpty) {
      return null;
    }
    if (hashes.length != urlCount) {
      throw ArgumentError(
        'Expected $urlCount MD5 hashes to match $urlCount URLs but got '
        '${hashes.length}',
      );
    }

    final invalidHashes = hashes.where((hash) => !_isMd5Hash(hash)).toList();
    if (invalidHashes.isNotEmpty) {
      throw ArgumentError(
        'Invalid MD5 hash "${invalidHashes.first}". '
        'Expected 32 hexadecimal characters.',
      );
    }
    return hashes;
  }

  static List<String> _readUrls(Map<String, String> environment) {
    final urlsFile = _firstNonEmpty(
      _argUrlsFile,
      environment['BRISK_STRESS_URLS_FILE'],
    );
    final urls = <String>[];
    if (urlsFile != null) {
      urls.addAll(
        File(urlsFile)
            .readAsLinesSync()
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty && !line.startsWith('#')),
      );
    }

    final singleUrl = _firstNonEmpty(_argUrl);
    if (singleUrl != null) {
      urls.add(singleUrl);
    }

    final rawUrls = _firstNonEmpty(_argUrls, environment['BRISK_STRESS_URLS']);
    if (rawUrls != null) {
      urls.addAll(
        rawUrls
            .split(',')
            .map((url) => url.trim())
            .where((url) => url.isNotEmpty),
      );
    }
    return urls;
  }
}

String? _firstNonEmpty(String? first, [String? second]) {
  if (first != null && first.trim().isNotEmpty) {
    return first;
  }
  if (second != null && second.trim().isNotEmpty) {
    return second;
  }
  return null;
}

bool _parseBool(String? value, {bool defaultValue = false}) {
  final normalized = value?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return defaultValue;
  }
  switch (normalized) {
    case 'true':
    case '1':
    case 'yes':
    case 'on':
      return true;
    case 'false':
    case '0':
    case 'no':
    case 'off':
      return false;
  }
  throw ArgumentError("Expected a boolean flag but got $value");
}

int _parsePositiveInt(String? value, {required int defaultValue}) {
  final parsed = int.tryParse(value ?? '') ?? defaultValue;
  if (parsed <= 0) {
    throw ArgumentError('Expected a positive integer but got $value');
  }
  return parsed;
}

int _parseNonNegativeInt(String? value, {required int defaultValue}) {
  final parsed = int.tryParse(value ?? '') ?? defaultValue;
  if (parsed < 0) {
    throw ArgumentError('Expected a non-negative integer but got $value');
  }
  return parsed;
}
