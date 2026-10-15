import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

class AppStorageService {
  static const String externalRootFolder = "/storage/emulated/0/RhyThm Music";
  static const String externalDataFolder = "$externalRootFolder/.data";
  static const String externalDataFolderVisible = "$externalRootFolder/Data";
  static const String externalMusicFolder = "$externalRootFolder/Music";
  static const String configFileName = "app_storage_type.txt";

  static String? _cachedStorageType;

  /// Returns active external data folder (checking visible Data vs hidden .data)
  static String getActiveExternalDataFolder() {
    try {
      final visibleDir = Directory(externalDataFolderVisible);
      if (visibleDir.existsSync()) {
        final hiveFiles = visibleDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.hive'))
            .toList();
        if (hiveFiles.isNotEmpty) {
          return externalDataFolderVisible;
        }
      }
    } catch (_) {}
    return externalDataFolder;
  }

  /// Gets user-selected storage type: 'external' or 'internal' (default).
  static Future<String> getAppStorageType() async {
    if (!GetPlatform.isAndroid) {
      return "internal";
    }
    if (_cachedStorageType != null) {
      return _cachedStorageType!;
    }
    try {
      final supportDir = (await getApplicationSupportDirectory()).path;
      final configFile = File("$supportDir/$configFileName");
      if (await configFile.exists()) {
        final val = (await configFile.readAsString()).trim();
        if (val == "internal" || val == "external") {
          _cachedStorageType = val;
          return val;
        }
      }
    } catch (e) {
      debugPrint("Error reading app storage config from supportDir: $e");
    }

    try {
      final docDir = (await getApplicationDocumentsDirectory()).path;
      final docConfigFile = File("$docDir/$configFileName");
      if (await docConfigFile.exists()) {
        final val = (await docConfigFile.readAsString()).trim();
        if (val == "internal" || val == "external") {
          _cachedStorageType = val;
          return val;
        }
      }
    } catch (e) {
      debugPrint("Error reading app storage config from docDir: $e");
    }

    // Fallback: check config in external folder if previously stored there
    try {
      final extConfigFile = File("$externalRootFolder/$configFileName");
      if (await extConfigFile.exists()) {
        final val = (await extConfigFile.readAsString()).trim();
        if (val == "internal" || val == "external") {
          _cachedStorageType = val;
          return val;
        }
      }
    } catch (_) {}

    return "internal";
  }

  /// Sets the storage type and persists it to both local config directories and external
  static Future<void> setAppStorageType(String type) async {
    _cachedStorageType = type;
    try {
      final supportDir = (await getApplicationSupportDirectory()).path;
      final configFile = File("$supportDir/$configFileName");
      await configFile.writeAsString(type);
    } catch (e) {
      debugPrint("Error writing app storage config to supportDir: $e");
    }

    try {
      final docDir = (await getApplicationDocumentsDirectory()).path;
      final docConfigFile = File("$docDir/$configFileName");
      await docConfigFile.writeAsString(type);
    } catch (e) {
      debugPrint("Error writing app storage config to docDir: $e");
    }

    try {
      final extRoot = Directory(externalRootFolder);
      if (await extRoot.exists()) {
        final extConfigFile = File("$externalRootFolder/$configFileName");
        await extConfigFile.writeAsString(type);
      }
    } catch (_) {}
  }

  /// Ensures external folders exist if storage permission is granted
  static Future<bool> ensureExternalFoldersExist() async {
    if (!GetPlatform.isAndroid) return false;
    try {
      final rootDir = Directory(externalRootFolder);
      if (!await rootDir.exists()) {
        await rootDir.create(recursive: true);
      }

      // Try creating hidden .data folder
      try {
        final extDir = Directory(externalDataFolder);
        if (!await extDir.exists()) {
          await extDir.create(recursive: true);
        }
        final noMediaFile = File("$externalDataFolder/.nomedia");
        if (!await noMediaFile.exists()) {
          await noMediaFile.create();
        }
      } catch (e) {
        debugPrint("Notice: could not create hidden .data, using visible Data: $e");
      }

      // Ensure visible Data folder is also ready
      final visibleDir = Directory(externalDataFolderVisible);
      if (!await visibleDir.exists()) {
        await visibleDir.create(recursive: true);
      }

      final musicDir = Directory(externalMusicFolder);
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }
      return true;
    } catch (e) {
      debugPrint("Error ensuring external folders: $e");
      return false;
    }
  }

  /// Called in main() -> initHive() to determine where Hive boxes should be opened.
  static Future<String> initAndGetActiveDataDirectory() async {
    if (GetPlatform.isDesktop) {
      final dir = "${(await getApplicationSupportDirectory()).path}/db";
      final d = Directory(dir);
      if (!await d.exists()) await d.create(recursive: true);
      return dir;
    }

    if (!GetPlatform.isAndroid) {
      return (await getApplicationDocumentsDirectory()).path;
    }

    final storageType = await getAppStorageType();
    final internalDocsDir = (await getApplicationDocumentsDirectory()).path;

    if (storageType == "internal") {
      return internalDocsDir;
    }

    // Attempt to use external storage
    try {
      final ok = await ensureExternalFoldersExist();
      if (!ok) {
        debugPrint("Could not create external folders, using internal");
        return internalDocsDir;
      }

      final extFolder = getActiveExternalDataFolder();

      // Verify read & write access
      final testFile = File("$extFolder/.test_access");
      await testFile.writeAsString("ok");
      await testFile.delete();

      // Check if external data is missing Hive files, auto-migrate from internal if needed
      await _checkAndAutoMigrate(
          fromDir: internalDocsDir, toDir: extFolder);

      // Clean up any stray .lock files in external folder
      final extDir = Directory(extFolder);
      if (await extDir.exists()) {
        final files = extDir.listSync().whereType<File>();
        for (final f in files) {
          if (f.path.endsWith('.lock')) {
            try {
              await f.delete();
            } catch (_) {}
          }
        }
      }

      debugPrint("Successfully using EXTERNAL storage: $extFolder");
      return extFolder;
    } catch (e) {
      debugPrint(
          "External storage not accessible during init ($e), falling back to internal: $internalDocsDir");
      return internalDocsDir;
    }
  }

  /// Returns current active directory path for dbDir in Settings/Backup/Restore
  static Future<String> getActiveDataDirectory() async {
    if (GetPlatform.isDesktop) {
      return "${(await getApplicationSupportDirectory()).path}/db";
    }
    if (!GetPlatform.isAndroid) {
      return (await getApplicationDocumentsDirectory()).path;
    }
    final storageType = await getAppStorageType();
    if (storageType == "internal") {
      return (await getApplicationDocumentsDirectory()).path;
    }
    try {
      final extFolder = getActiveExternalDataFolder();
      final extDir = Directory(extFolder);
      if (await extDir.exists()) {
        final testFile = File("$extFolder/.test_access");
        await testFile.writeAsString("ok");
        await testFile.delete();
        return extFolder;
      }
    } catch (_) {}
    return (await getApplicationDocumentsDirectory()).path;
  }

  /// Auto-migrates files from internal to external if external has no data yet
  static Future<void> _checkAndAutoMigrate({
    required String fromDir,
    required String toDir,
  }) async {
    try {
      final toDirectory = Directory(toDir);
      final fromDirectory = Directory(fromDir);

      if (!await fromDirectory.exists()) return;

      final existingToHive = toDirectory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.hive'))
          .toList();

      if (existingToHive.isEmpty) {
        // External has no hive files yet, copy from internal without overwriting
        final fromFiles = fromDirectory.listSync().whereType<File>().toList();
        for (final file in fromFiles) {
          if (file.path.endsWith('.hive')) {
            final fileName = file.uri.pathSegments.last;
            final destFile = File("$toDir/$fileName");
            if (!await destFile.exists()) {
              await file.copy(destFile.path);
            }
          }
        }
        debugPrint("Auto-migrated Hive data files from $fromDir to $toDir");
      }
    } catch (e) {
      debugPrint("Error in auto-migration: $e");
    }
  }

  /// Full migration between internal and external
  static Future<bool> copyAllHiveData({
    required String fromDir,
    required String toDir,
  }) async {
    try {
      final fromDirectory = Directory(fromDir);
      final toDirectory = Directory(toDir);

      if (!await toDirectory.exists()) {
        await toDirectory.create(recursive: true);
      }
      if (toDir.contains(externalRootFolder)) {
        final noMedia = File("$toDir/.nomedia");
        if (!await noMedia.exists()) {
          try {
            await noMedia.create();
          } catch (_) {}
        }
      }

      if (await fromDirectory.exists()) {
        final fromFiles = fromDirectory.listSync().whereType<File>().toList();
        for (final file in fromFiles) {
          // IMPORTANT: Copy ONLY .hive files. Never copy .lock files!
          // NEVER overwrite existing files in destination so user's data is strictly preserved!
          if (file.path.endsWith('.hive')) {
            final fileName = file.uri.pathSegments.last;
            final destFile = File("$toDir/$fileName");
            if (!await destFile.exists()) {
              await file.copy(destFile.path);
            }
          }
        }
      }

      // Also migrate music files from source Music folder to target Music folder
      final supportDir = (await getApplicationSupportDirectory()).path;
      final internalMusicPath = "$supportDir/Music";
      final fromMusicDir = Directory(fromDir.contains(externalRootFolder)
          ? externalMusicFolder
          : internalMusicPath);
      final toMusicDir = Directory(toDir.contains(externalRootFolder)
          ? externalMusicFolder
          : internalMusicPath);

      if (await fromMusicDir.exists() && fromMusicDir.path != toMusicDir.path) {
        if (!await toMusicDir.exists()) {
          await toMusicDir.create(recursive: true);
        }
        final musicFiles = fromMusicDir.listSync().whereType<File>().toList();
        for (final mFile in musicFiles) {
          final mFileName = mFile.uri.pathSegments.last;
          final destMusicFile = File("${toMusicDir.path}/$mFileName");
          if (!await destMusicFile.exists()) {
            try {
              await mFile.copy(destMusicFile.path);
            } catch (e) {
              debugPrint("Error copying music file $mFileName: $e");
            }
          }
        }
      }

      // Clean up any existing .lock files in the destination
      if (await toDirectory.exists()) {
        final toFiles = toDirectory.listSync().whereType<File>().toList();
        for (final file in toFiles) {
          if (file.path.endsWith('.lock')) {
            try {
              await file.delete();
            } catch (_) {}
          }
        }
      }

      return true;
    } catch (e) {
      debugPrint("Error migrating Hive data: $e");
      return false;
    }
  }

  /// Default download directory
  static Future<String> getDefaultDownloadDirectory() async {
    final storageType = await getAppStorageType();
    if (GetPlatform.isAndroid && storageType == "external") {
      try {
        final dir = Directory(externalMusicFolder);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return externalMusicFolder;
      } catch (e) {
        debugPrint("Error creating external music folder: $e");
      }
    }
    final supportDir = (await getApplicationSupportDirectory()).path;
    final dir = Directory("$supportDir/Music");
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return "$supportDir/Music";
  }
}
