import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/source_profile.dart';

part 'source_profile_repository.g.dart';

abstract class SourceProfileRepository {
  Future<List<SourceProfile>> loadProfiles();

  Future<void> saveProfiles(List<SourceProfile> profiles);

  Future<String?> loadActiveSourceId();

  Future<void> saveActiveSourceId(String? sourceId);
}

class SecureSourceProfileRepository implements SourceProfileRepository {
  SecureSourceProfileRepository(this._storage);

  static const _profilesKey = 'source_profiles_v1';
  static const _activeSourceKey = 'active_source_id_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<List<SourceProfile>> loadProfiles() async {
    final raw = await _storage.read(key: _profilesKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    final profiles = decoded
        .map((item) => SourceProfile.fromJson(item as Map<String, dynamic>))
        .toList();
    profiles.sort(
      (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    return profiles;
  }

  @override
  Future<void> saveProfiles(List<SourceProfile> profiles) {
    final encoded = jsonEncode(
      profiles.map((profile) => profile.toJson()).toList(),
    );
    return _storage.write(key: _profilesKey, value: encoded);
  }

  @override
  Future<String?> loadActiveSourceId() {
    return _storage.read(key: _activeSourceKey);
  }

  @override
  Future<void> saveActiveSourceId(String? sourceId) async {
    if (sourceId == null || sourceId.isEmpty) {
      await _storage.delete(key: _activeSourceKey);
      return;
    }
    await _storage.write(key: _activeSourceKey, value: sourceId);
  }
}

@Riverpod(keepAlive: true)
SourceProfileRepository sourceProfileRepository(Ref ref) {
  return SecureSourceProfileRepository(const FlutterSecureStorage());
}
