import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum DownloadsAccessIssue {
  /// XDG_DOWNLOAD_DIR is not set, so Flatpak ignores the xdg-download
  /// permission and no folder is shared with the sandbox.
  notConfigured,

  /// The folder is not shared with the sandbox: it doesn't exist on the host,
  /// or the xdg-download permission was removed (e.g. with Flatseal).
  notShared,

  /// The folder is shared, but Brisk cannot write to it.
  notWritable,
}

class DownloadsAccessProblem {
  final DownloadsAccessIssue issue;

  /// The resolved Downloads path. Null when [issue] is
  /// [DownloadsAccessIssue.notConfigured].
  final String? path;

  const DownloadsAccessProblem(this.issue, [this.path]);
}

/// Checks that the Flatpak sandbox can save files to the user's Downloads
/// folder. Inside Flatpak the root filesystem is a private tmpfs, so a path
/// that isn't bind-mounted from the host looks writable but its files vanish
/// when the app exits. That case must be detected explicitly.
class DownloadsAccessCheck {
  /// Returns null when the Downloads folder is usable.
  static Future<DownloadsAccessProblem?> run() async {
    final home = Platform.environment['HOME'];
    String? path;
    try {
      path = (await getDownloadsDirectory())?.path;
    } catch (_) {}
    // `xdg-user-dir DOWNLOAD` falls back to $HOME when XDG_DOWNLOAD_DIR is unset
    if (path == null ||
        path.isEmpty ||
        (home != null && p.equals(p.normalize(path), p.normalize(home)))) {
      return const DownloadsAccessProblem(DownloadsAccessIssue.notConfigured);
    }
    final dir = Directory(path);
    if (!dir.existsSync() || !_isSharedWithHost(dir)) {
      return DownloadsAccessProblem(DownloadsAccessIssue.notShared, path);
    }
    if (!await _isWritable(dir)) {
      return DownloadsAccessProblem(DownloadsAccessIssue.notWritable, path);
    }
    return null;
  }

  /// Whether [dir] is covered by a bind mount other than the sandbox root.
  static bool _isSharedWithHost(Directory dir) {
    final mountPoints = _readMountPoints();
    // Can't tell without mountinfo; don't block the user on a guess.
    if (mountPoints.isEmpty) return true;
    String target;
    try {
      target = p.normalize(dir.resolveSymbolicLinksSync());
    } catch (_) {
      target = p.normalize(p.absolute(dir.path));
    }
    String? covering;
    for (final mountPoint in mountPoints) {
      if (mountPoint == '/' ||
          target == mountPoint ||
          p.isWithin(mountPoint, target)) {
        if (covering == null || mountPoint.length > covering.length) {
          covering = mountPoint;
        }
      }
    }
    return covering != null && covering != '/';
  }

  static List<String> _readMountPoints() {
    try {
      return File('/proc/self/mountinfo')
          .readAsLinesSync()
          .map((line) => line.split(' '))
          .where((fields) => fields.length > 4)
          // mountinfo escapes spaces and other characters as octal (\040)
          .map((fields) => fields[4].replaceAllMapped(
                RegExp(r'\\([0-7]{3})'),
                (m) => String.fromCharCode(int.parse(m[1]!, radix: 8)),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> _isWritable(Directory dir) async {
    final probe = File(p.join(dir.path, '.brisk-write-test-$pid'));
    try {
      await probe.writeAsString('');
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}
