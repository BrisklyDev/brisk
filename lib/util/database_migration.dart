import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

const _oldLinuxAppId = "com.aminbhst.brisk";
const _linuxAppId = "io.github.BrisklyDev.Brisk";

/// The Linux application ID changed from [_oldLinuxAppId] to [_linuxAppId].
/// path_provider_linux derives the application support directory from the
/// application ID, so the existing data directory must be moved before
/// anything calls getApplicationSupportDirectory(). Otherwise the app would
/// start with an empty database.
///
/// A symlink is left at the old location so that downgrading keeps working.
/// Must run before Logger.init().
void migrateLinuxAppIdDataDir() {
  if (!Platform.isLinux) return;
  try {
    final dataHome = _xdgDataHome();
    if (dataHome == null) return;
    final oldDir = Directory(path.join(dataHome, _oldLinuxAppId));
    final newDir = Directory(path.join(dataHome, _linuxAppId));
    if (FileSystemEntity.typeSync(oldDir.path, followLinks: false) !=
            FileSystemEntityType.directory ||
        FileSystemEntity.typeSync(newDir.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
      return;
    }
    try {
      oldDir.renameSync(newDir.path);
      Link(oldDir.path).createSync(newDir.path);
    } catch (e) {
      // Rename failed: point the new location at the old data instead.
      if (!newDir.existsSync()) {
        Link(newDir.path).createSync(oldDir.path);
      }
    }
  } catch (e) {
    print("Failed to migrate Linux data directory: $e");
  }
}

/// Mirrors the xdg_directories package used by path_provider_linux.
String? _xdgDataHome() {
  final xdgDataHome = Platform.environment["XDG_DATA_HOME"];
  if (xdgDataHome != null && xdgDataHome.isNotEmpty) return xdgDataHome;
  final home = Platform.environment["HOME"];
  if (home == null || home.isEmpty) return null;
  return path.join(home, ".local", "share");
}

Future<void> migrateDatabaseLocation() async {
  final documentsDir = await getApplicationDocumentsDirectory();
  final oldDbPath = path.join(documentsDir.path, "Brisk_v2");
  final oldDbDir = Directory(oldDbPath);
  if (!oldDbDir.existsSync()) {
    return;
  }
  final appSupportDir = await getApplicationSupportDirectory();
  final newPath = path.join(appSupportDir.path);
  Directory(newPath).createSync(recursive: true);
  for (final file in oldDbDir.listSync()) {
    if (file is File) {
      final fileName = path.basename(file.path);
      final newFilePath = path.join(newPath, fileName);
      await file.rename(newFilePath);
    }
  }
  oldDbDir.deleteSync();
}
