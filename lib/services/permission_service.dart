import 'dart:io';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '/native_bindings/andrid_utils.dart' show SDKInt;

class PermissionService {
  static int _getSdkInt() {
    try {
      return SDKInt.Companion.getSDKInt();
    } catch (_) {
      return 33; // Default to modern Android if JNI binding fails
    }
  }

  static Future<bool> isStoragePermissionGranted() async {
    if (GetPlatform.isDesktop) {
      return true;
    }
    // Direct write test on external folder first
    try {
      final testDir = Directory("/storage/emulated/0/RhyThm Music");
      if (!await testDir.exists()) await testDir.create(recursive: true);
      final testFile = File("/storage/emulated/0/RhyThm Music/.perm_test");
      await testFile.writeAsString("ok");
      await testFile.delete();
      return true;
    } catch (_) {}

    try {
      if (await Permission.manageExternalStorage.isGranted) return true;
      if (await Permission.storage.isGranted) return true;
    } catch (_) {}

    final sdk = _getSdkInt();
    if (sdk < 30) {
      return (await Permission.storage.status).isGranted;
    } else {
      return await Permission.manageExternalStorage.isGranted;
    }
  }

  static Future<bool> getExtStoragePermission() async {
    if (GetPlatform.isDesktop) {
      return true;
    }

    // First check if direct access already works
    if (await isStoragePermissionGranted()) {
      return true;
    }

    final sdk = _getSdkInt();
    if (sdk < 30) {
      var status = await Permission.storage.status;
      if (status.isDenied) {
        await [
          Permission.storage,
          Permission.accessMediaLocation,
          Permission.mediaLibrary,
        ].request();
      }

      if (await isStoragePermissionGranted() || (await Permission.storage.status).isGranted) {
        return true;
      }

      if (await Permission.storage.isPermanentlyDenied) {
        await openAppSettings();
      }

      return await isStoragePermissionGranted() || (await Permission.storage.status).isGranted;
    } else {
      if (!await Permission.manageExternalStorage.isGranted) {
        await Permission.manageExternalStorage.request();
        if (await isStoragePermissionGranted() || await Permission.manageExternalStorage.isGranted) {
          return true;
        }

        // Also request standard storage/audio permissions as fallback
        await [
          Permission.storage,
          Permission.audio,
        ].request();

        if (await isStoragePermissionGranted()) {
          return true;
        }

        if (await Permission.manageExternalStorage.isPermanentlyDenied) {
          await openAppSettings();
        }

        return await isStoragePermissionGranted() || await Permission.manageExternalStorage.isGranted;
      }
      return true;
    }
  }
}
