import 'dart:io';

import 'package:brisk/util/downloads_access_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Shown instead of the app when the Flatpak sandbox can't use the Downloads
/// folder. It explains the problem and how to fix it, and only lets the user
/// quit: Flatpak applies permission changes on the next launch.
class DownloadsAccessRequiredApp extends StatelessWidget {
  final DownloadsAccessProblem problem;

  const DownloadsAccessRequiredApp({super.key, required this.problem});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Brisk',
      theme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: _DownloadsAccessRequiredPage(problem: problem),
    );
  }
}

class _DownloadsAccessRequiredPage extends StatelessWidget {
  final DownloadsAccessProblem problem;

  const _DownloadsAccessRequiredPage({required this.problem});

  String get _appId =>
      Platform.environment['FLATPAK_ID'] ?? 'io.github.BrisklyDev.Brisk';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_off_rounded,
                        size: 32, color: theme.colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Brisk can't access your Downloads folder",
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Brisk saves files to your Downloads folder. The Flatpak '
                  'version can only reach it when the folder is set up and '
                  'shared with the app.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                ..._steps(theme),
                const SizedBox(height: 16),
                Text(
                  'Then reopen Brisk. Flatpak applies these changes on the '
                  'next launch.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => exit(0),
                    child: const Text('Quit'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// [path] relative to the home folder, or null when it is outside it.
  String? _relativeToHome(String path) {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty || !p.isWithin(home, path)) return null;
    return p.relative(path, from: home);
  }

  /// [path] for display, with the home folder shortened to `~`.
  String _displayPath(String path) {
    final relative = _relativeToHome(path);
    return relative == null ? path : '~/$relative';
  }

  /// [path] as a shell argument. Uses `~/...` when no quoting is needed,
  /// and `"$HOME/..."` otherwise, since the shell doesn't expand a quoted `~`.
  String _shellPath(String path) {
    final relative = _relativeToHome(path);
    if (relative != null && RegExp(r'^[\w./-]+$').hasMatch(relative)) {
      return '~/$relative';
    }
    final escaped = (relative ?? path)
        .replaceAllMapped(RegExp(r'[\\"$`]'), (m) => '\\${m[0]}');
    return relative == null ? '"$escaped"' : '"\$HOME/$escaped"';
  }

  List<Widget> _steps(ThemeData theme) {
    final path = problem.path ?? '';
    switch (problem.issue) {
      case DownloadsAccessIssue.notConfigured:
        return [
          _paragraph(
            theme,
            "Your system doesn't define a Downloads folder "
            '(XDG_DOWNLOAD_DIR is not set), so Flatpak has no folder to '
            'share with Brisk. Set ~/Downloads as your Downloads folder:',
          ),
          ..._setDownloadsDirSteps(theme, '~/Downloads', '\$HOME/Downloads'),
        ];
      case DownloadsAccessIssue.notShared:
        return [
          _paragraph(
            theme,
            'Your Downloads folder (${_displayPath(path)}) '
            "isn't shared with Brisk. The folder may not exist, it may not "
            'be set as your Downloads folder (XDG_DOWNLOAD_DIR), or the '
            'Downloads permission was removed (for example in Flatseal).',
          ),
          _paragraph(
            theme,
            '1. Create the folder and set it as your Downloads folder:',
          ),
          ..._setDownloadsDirSteps(
            theme,
            _shellPath(path),
            _userDirsPath(path),
          ),
          _paragraph(theme, '2. Give Brisk access to it again:'),
          _Command('flatpak override --user --filesystem=xdg-download $_appId'),
        ];
      case DownloadsAccessIssue.notWritable:
        return [
          _paragraph(
            theme,
            "Brisk can't write to your Downloads folder "
            '(${_displayPath(path)}). Make sure your user owns the folder '
            'and can write to it:',
          ),
          _Command('chmod u+w ${_shellPath(path)}'),
        ];
    }
  }

  /// Commands that create [shellPath] and register it as XDG_DOWNLOAD_DIR.
  /// [userDirsPath] is the same folder in user-dirs.dirs syntax, which
  /// accepts `$HOME/...` or an absolute path, but not `~`.
  List<Widget> _setDownloadsDirSteps(
    ThemeData theme,
    String shellPath,
    String userDirsPath,
  ) =>
      [
        _Command(
          'mkdir -p $shellPath && '
          'xdg-user-dirs-update --set DOWNLOAD $shellPath',
        ),
        _paragraph(
          theme,
          "If xdg-user-dirs-update isn't installed, run this instead. It "
          'adds the Downloads folder to ~/.config/user-dirs.dirs, the file '
          'that tells Linux where your Downloads folder is, and creates the '
          "file if it doesn't exist:",
        ),
        _Command(
          'mkdir -p ~/.config && echo '
          "'${'XDG_DOWNLOAD_DIR="$userDirsPath"'.replaceAll("'", r"'\''")}' "
          '>> ~/.config/user-dirs.dirs',
        ),
      ];

  /// [path] in user-dirs.dirs syntax: `$HOME/...` inside the home folder.
  String _userDirsPath(String path) {
    final relative = _relativeToHome(path);
    final value = relative == null ? path : '\$HOME/$relative';
    return value.replaceAllMapped(RegExp(r'[\\"`]'), (m) => '\\${m[0]}');
  }

  Widget _paragraph(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text, style: theme.textTheme.bodyLarge),
      );
}

/// A shell command with a copy button.
class _Command extends StatelessWidget {
  final String command;

  const _Command(this.command);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              command,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () => Clipboard.setData(ClipboardData(text: command)),
          ),
        ],
      ),
    );
  }
}
