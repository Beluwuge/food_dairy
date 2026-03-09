import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

class CacheCleaner {

  /// Clear cached network images
  static Future<void> clearImageCache() async {
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {}
  }

  /// Delete temporary image file
  static Future<void> deleteTempFile(String? path) async {
    if (path == null || path.isEmpty) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Remove unused files inside /cache folder
  static Future<void> cleanAppCacheFolder() async {
    try {
      final tempDir = await getTemporaryDirectory();

      if (!await tempDir.exists()) return;

      final files = tempDir.listSync(recursive: true);

      for (final f in files) {
        if (f is File) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Run full cleanup
  static Future<void> fullCleanup() async {
    await clearImageCache();
    await cleanAppCacheFolder();
  }
}