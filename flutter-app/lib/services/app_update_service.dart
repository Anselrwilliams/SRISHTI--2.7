import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseUrl;

  const AppUpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseUrl,
  });

  @override
  String toString() =>
      'AppUpdateInfo(version: $version, downloadUrl: $downloadUrl)';
}

/// Structured semantic version model for app version comparisons.
class AppVersion implements Comparable<AppVersion> {
  final int major;
  final int minor;
  final int patch;
  final int build;
  final String raw;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.build = 0,
    required this.raw,
  });

  /// Standard semantic version regex:
  /// Matches standard tags such as "v1.0.3", "1.0.3", "v1.0.3+4", "1.0.3+4".
  /// Rejects tags with arbitrary text suffixes like "v1.0.2-profile-about".
  static final RegExp standardTagRegex =
      RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$');

  /// Attempts to parse standard semantic version strings.
  /// Returns null if the input has arbitrary text suffixes or does not match.
  static AppVersion? tryParse(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final clean = input.trim();
    final match = standardTagRegex.firstMatch(clean);
    if (match == null) return null;

    final major = int.tryParse(match.group(1)!) ?? 0;
    final minor = int.tryParse(match.group(2)!) ?? 0;
    final patch = int.tryParse(match.group(3)!) ?? 0;
    final buildStr = match.group(4);
    final build = buildStr != null ? (int.tryParse(buildStr) ?? 0) : 0;

    return AppVersion(
      major: major,
      minor: minor,
      patch: patch,
      build: build,
      raw: clean,
    );
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (build != other.build) return build.compareTo(other.build);
    return 0;
  }

  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  String toString() =>
      '$major.$minor.$patch${build > 0 ? '+$build' : ''}';
}

class AppUpdateService {
  static const String _releasesUrl =
      'https://api.github.com/repos/Anselrwilliams/SRISHTI--2.7/releases';
  static const String _latestReleaseUrl =
      'https://api.github.com/repos/Anselrwilliams/SRISHTI--2.7/releases/latest';

  /// Session tracking to ensure update dialog is shown at most once per session.
  static bool hasShownDialog = false;
  static bool isCheckInProgress = false;

  /// Resets session tracking state (primarily for testing and session restart).
  static void resetSession() {
    hasShownDialog = false;
    isCheckInProgress = false;
  }

  /// Checks GitHub releases for a newer APK version than the installed app.
  static Future<AppUpdateInfo?> checkForUpdate({
    http.Client? client,
    PackageInfo? packageInfo,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      // 1. Determine installed version
      AppVersion? installedVersion;
      if (packageInfo != null) {
        installedVersion = _parsePackageInfo(packageInfo);
      } else {
        try {
          final info = await PackageInfo.fromPlatform();
          installedVersion = _parsePackageInfo(info);
        } catch (e) {
          debugPrint('[AppUpdateService] Failed to load package metadata: $e');
          return null;
        }
      }

      if (installedVersion == null) {
        debugPrint('[AppUpdateService] Could not parse installed app version.');
        return null;
      }

      debugPrint(
        '[AppUpdateService] Checking for updates. Installed version: $installedVersion',
      );

      // 2. Query GitHub releases
      http.Response response;
      try {
        response = await httpClient.get(
          Uri.parse(_releasesUrl),
          headers: const {
            'Accept': 'application/vnd.github+json',
          },
        );
      } catch (e) {
        debugPrint('[AppUpdateService] Network request to releases failed: $e');
        return null;
      }

      // If /releases fails, attempt /releases/latest fallback
      if (response.statusCode != 200) {
        debugPrint(
          '[AppUpdateService] GitHub releases query failed (status: ${response.statusCode}), falling back to latest endpoint.',
        );
        try {
          response = await httpClient.get(
            Uri.parse(_latestReleaseUrl),
            headers: const {
              'Accept': 'application/vnd.github+json',
            },
          );
        } catch (e) {
          debugPrint('[AppUpdateService] Network request to latest endpoint failed: $e');
          return null;
        }

        if (response.statusCode != 200) {
          debugPrint(
            '[AppUpdateService] GitHub latest endpoint failed with status: ${response.statusCode}',
          );
          return null;
        }
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (e) {
        debugPrint('[AppUpdateService] Failed to decode GitHub response: $e');
        return null;
      }

      final List<dynamic> releasesList;
      if (decoded is List) {
        releasesList = decoded;
      } else if (decoded is Map<String, dynamic>) {
        releasesList = [decoded];
      } else {
        debugPrint('[AppUpdateService] Malformed GitHub API response structure.');
        return null;
      }

      // 3. Find highest candidate release matching standard semantic version
      AppVersion? highestVersion;
      String? bestDownloadUrl;
      String? bestReleaseUrl;

      for (final item in releasesList) {
        if (item is! Map<String, dynamic>) continue;

        // Ensure release is published, not a draft or prerelease
        final isDraft = item['draft'] == true;
        final isPrerelease = item['prerelease'] == true;
        if (isDraft || isPrerelease) {
          continue;
        }

        final tagName = item['tag_name'] as String?;
        final releaseUrl = item['html_url'] as String?;
        if (tagName == null || releaseUrl == null) continue;

        final candidateVersion = AppVersion.tryParse(tagName);
        if (candidateVersion == null) {
          debugPrint(
            '[AppUpdateService] Ignoring non-standard/metadata release tag: $tagName',
          );
          continue;
        }

        // Look for valid APK asset
        final assets = item['assets'] as List<dynamic>? ?? [];
        String? apkDownloadUrl;
        for (final asset in assets) {
          if (asset is! Map<String, dynamic>) continue;
          final name = asset['name'] as String?;
          final downloadUrl = asset['browser_download_url'] as String?;
          if (name != null &&
              name.toLowerCase().endsWith('.apk') &&
              downloadUrl != null &&
              downloadUrl.isNotEmpty) {
            apkDownloadUrl = downloadUrl;
            break;
          }
        }

        if (apkDownloadUrl == null) {
          debugPrint(
            '[AppUpdateService] Release $tagName has no downloadable APK asset.',
          );
          continue;
        }

        if (highestVersion == null ||
            candidateVersion.isNewerThan(highestVersion)) {
          highestVersion = candidateVersion;
          bestDownloadUrl = apkDownloadUrl;
          bestReleaseUrl = releaseUrl;
        }
      }

      if (highestVersion == null ||
          bestDownloadUrl == null ||
          bestReleaseUrl == null) {
        debugPrint(
          '[AppUpdateService] No eligible standard release with an APK asset was found.',
        );
        return null;
      }

      // 4. Compare with installed version
      if (highestVersion.isNewerThan(installedVersion)) {
        debugPrint(
          '[AppUpdateService] Update available: release $highestVersion > installed $installedVersion',
        );
        return AppUpdateInfo(
          version: highestVersion.toString(),
          downloadUrl: bestDownloadUrl,
          releaseUrl: bestReleaseUrl,
        );
      } else {
        debugPrint(
          '[AppUpdateService] Installed app ($installedVersion) is up to date with release ($highestVersion).',
        );
        return null;
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Unexpected error during update check: $e');
      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  static AppVersion? _parsePackageInfo(PackageInfo info) {
    final versionStr = info.version.trim();
    final buildStr = info.buildNumber.trim();
    if (versionStr.isEmpty) return null;
    final combined = buildStr.isNotEmpty ? '$versionStr+$buildStr' : versionStr;
    return AppVersion.tryParse(combined) ?? AppVersion.tryParse(versionStr);
  }
}
