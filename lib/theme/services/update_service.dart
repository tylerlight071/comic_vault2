// lib/theme/services/update_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String currentVersion;
  final String remoteVersion;
  final bool hasUpdate;
  final bool forceUpdate;
  final List<String> changelog;

  const UpdateInfo({
    required this.currentVersion,
    required this.remoteVersion,
    required this.hasUpdate,
    required this.forceUpdate,
    required this.changelog,
  });
}

class UpdateService {
  static const _versionUrl =
      'https://raw.githubusercontent.com/tylerlight071/comic_vault2/main/version.json';

  static Future<UpdateInfo?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final response = await http
          .get(Uri.parse(_versionUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteVersion = json['version'] as String? ?? currentVersion;
      final forceUpdate   = json['forceUpdate'] as bool? ?? false;
      final changelog     = (json['changelog'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      final hasUpdate = _isNewer(remoteVersion, currentVersion);

      return UpdateInfo(
        currentVersion: currentVersion,
        remoteVersion: remoteVersion,
        hasUpdate: hasUpdate,
        forceUpdate: forceUpdate && hasUpdate,
        changelog: changelog,
      );
    } catch (e) {
      debugPrint('[UpdateService] check failed: $e');
      return null;
    }
  }

  /// Returns true if [remote] is a higher semver than [current].
  static bool _isNewer(String remote, String current) {
    final r = _parse(remote);
    final c = _parse(current);
    for (var i = 0; i < 3; i++) {
      if (r[i] > c[i]) return true;
      if (r[i] < c[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String v) {
    final parts = v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) parts.add(0);
    return parts;
  }
}
