import 'dart:convert';

import 'package:http/http.dart' as http;

class AppUpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseUrl;

  const AppUpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseUrl,
  });
}

class AppUpdateService {
  static const String _latestReleaseUrl =
      'https://api.github.com/repos/Anselrwilliams/SRISHTI--2.7/releases/latest';

  static const String currentVersion = '1.0.1';

  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(_latestReleaseUrl),
        headers: const {
          'Accept': 'application/vnd.github+json',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final tagName = data['tag_name'] as String?;
      final releaseUrl = data['html_url'] as String?;

      if (tagName == null || releaseUrl == null) {
        return null;
      }

      final latestVersion = tagName.startsWith('v')
          ? tagName.substring(1)
          : tagName;

      if (!_isNewerVersion(latestVersion, currentVersion)) {
        return null;
      }

      final assets = data['assets'] as List<dynamic>? ?? [];

      for (final asset in assets) {
        final assetMap = asset as Map<String, dynamic>;
        final name = assetMap['name'] as String?;

        if (name == null || !name.toLowerCase().endsWith('.apk')) {
          continue;
        }

        final downloadUrl = assetMap['browser_download_url'] as String?;

        if (downloadUrl == null) {
          continue;
        }

        return AppUpdateInfo(
          version: latestVersion,
          downloadUrl: downloadUrl,
          releaseUrl: releaseUrl,
        );
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static bool _isNewerVersion(String latest, String current) {
    final latestParts = _parseVersion(latest);
    final currentParts = _parseVersion(current);

    for (var i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) {
        return true;
      }

      if (latestParts[i] < currentParts[i]) {
        return false;
      }
    }

    return false;
  }

  static List<int> _parseVersion(String version) {
    final parts = version.split('.');

    return List.generate(3, (index) {
      if (index >= parts.length) {
        return 0;
      }

      return int.tryParse(parts[index]) ?? 0;
    });
  }
}
