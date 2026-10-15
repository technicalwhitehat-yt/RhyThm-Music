import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../ui/screens/Settings/settings_screen_controller.dart';
import '../ui/widgets/new_version_dialog.dart';
import '../ui/widgets/snackbar.dart';

class AppReleaseInfo {
  final String tagName;
  final String displayVersion;
  final String title;
  final String body;
  final String downloadUrl;
  final String fileName;
  final int fileSize;
  final bool hasUpdate;

  AppReleaseInfo({
    required this.tagName,
    required this.displayVersion,
    required this.title,
    required this.body,
    required this.downloadUrl,
    required this.fileName,
    required this.fileSize,
    required this.hasUpdate,
  });
}

class UpdateService {
  static const String repoReleasesUrl =
      "https://api.github.com/repos/technicalwhitehat-yt/RhyThm-Music/releases/latest";
  static const MethodChannel _installerChannel =
      MethodChannel("com.twh.rhythm_music/package_installer");

  /// Check GitHub latest release and compare with current app version
  static Future<AppReleaseInfo?> checkLatestRelease({String? curVer}) async {
    try {
      final currentVersion = curVer ??
          (Get.isRegistered<SettingsScreenController>()
              ? Get.find<SettingsScreenController>().currentVersion
              : "2.0.0");

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "RhyThm-Music-App",
          },
        ),
      );

      final response = await dio.get(repoReleasesUrl);
      if (response.statusCode != 200 || response.data == null) {
        return null;
      }

      final data = response.data as Map<String, dynamic>;
      final tagName = data["tag_name"]?.toString() ?? "";
      final releaseTitle = data["name"]?.toString() ?? tagName;
      final releaseBody = data["body"]?.toString() ?? "";
      final assets = (data["assets"] as List<dynamic>?) ?? [];

      // Extract version numbers from release tag
      final regExp = RegExp(r'(\d+)\.(\d+)(?:\.(\d+))?');
      final matchNew = regExp.firstMatch(tagName);
      final matchCur = regExp.firstMatch(currentVersion);

      bool hasUpdate = false;
      String displayVersion = tagName;

      if (matchNew != null) {
        final newMajor = int.parse(matchNew.group(1)!);
        final newMinor = int.parse(matchNew.group(2)!);
        final newPatch = int.parse(matchNew.group(3) ?? "0");
        displayVersion = "$newMajor.$newMinor.$newPatch";

        if (matchCur != null) {
          final curMajor = int.parse(matchCur.group(1)!);
          final curMinor = int.parse(matchCur.group(2)!);
          final curPatch = int.parse(matchCur.group(3) ?? "0");

          if (newMajor > curMajor) {
            hasUpdate = true;
          } else if (newMajor == curMajor && newMinor > curMinor) {
            hasUpdate = true;
          } else if (newMajor == curMajor &&
              newMinor == curMinor &&
              newPatch > curPatch) {
            hasUpdate = true;
          }
        } else {
          hasUpdate = true;
        }
      }

      // Smart APK Selection:
      // Priority 1: arm64-v8a or universal APK
      // Priority 2: first available APK
      String selectedDownloadUrl = "";
      String selectedFileName = "rhythm_music_update.apk";
      int selectedFileSize = 0;

      final apkAssets = assets.where((a) {
        final name = (a["name"] ?? "").toString().toLowerCase();
        return name.endsWith(".apk");
      }).toList();

      if (apkAssets.isNotEmpty) {
        // Priority 1: arm64-v8a or universal
        dynamic chosen = apkAssets.firstWhere((a) {
          final name = (a["name"] ?? "").toString().toLowerCase();
          return name.contains("arm64") ||
              name.contains("arm64-v8a") ||
              name.contains("universal");
        }, orElse: () => null);

        // Priority 2: first available apk
        chosen ??= apkAssets.first;

        selectedDownloadUrl = chosen["browser_download_url"]?.toString() ?? "";
        selectedFileName = chosen["name"]?.toString() ?? "rhythm_music_update.apk";
        selectedFileSize = chosen["size"] as int? ?? 0;
      } else {
        selectedDownloadUrl = data["html_url"]?.toString() ?? "";
      }

      return AppReleaseInfo(
        tagName: tagName,
        displayVersion: displayVersion,
        title: releaseTitle,
        body: releaseBody,
        downloadUrl: selectedDownloadUrl,
        fileName: selectedFileName,
        fileSize: selectedFileSize,
        hasUpdate: hasUpdate,
      );
    } catch (e) {
      debugPrint("Error checking latest release: $e");
      return null;
    }
  }

  /// Installs APK directly via native Android Package Installer Intent
  static Future<bool> installApk(String filePath) async {
    if (!GetPlatform.isAndroid) return false;
    try {
      final res = await _installerChannel.invokeMethod<bool>(
        "installApk",
        {"filePath": filePath},
      );
      return res ?? false;
    } catch (e) {
      debugPrint("Failed to launch package installer: $e");
      return false;
    }
  }

  /// Automatically deletes leftover update APKs on startup
  static Future<void> cleanOldUpdateFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final updateDir = Directory("${tempDir.path}/update");
      if (await updateDir.exists()) {
        final files = updateDir.listSync();
        for (final file in files) {
          if (file is File && file.path.endsWith('.apk')) {
            try {
              file.deleteSync();
              debugPrint("Cleaned up old update file: ${file.path}");
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint("Error cleaning old update files: $e");
    }
  }

  /// Manually checks or triggers update popup
  static Future<void> checkAndShowUpdateDialog(
    BuildContext context, {
    bool manualCheck = false,
  }) async {
    if (manualCheck) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackbar(
          context,
          "Checking for updates...",
          size: SanckBarSize.BIG,
          duration: const Duration(seconds: 1),
        ),
      );
    }

    final releaseInfo = await checkLatestRelease();

    if (!context.mounted) return;

    if (releaseInfo != null && releaseInfo.hasUpdate) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => NewVersionDialog(releaseInfo: releaseInfo),
      );
    } else if (manualCheck) {
      ScaffoldMessenger.of(context).showSnackBar(
        snackbar(
          context,
          "You're already using the latest version!",
          size: SanckBarSize.BIG,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
