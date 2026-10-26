import 'dart:convert';

/// A person charts are computed for: the user ("我") or someone they help.
/// Stored on the device only (encrypted) — never sent to the server except the
/// birth fields needed for a single chart computation; the name never leaves.
class BirthProfile {
  const BirthProfile({
    required this.id,
    required this.name,
    required this.gender,
    required this.birthLocal,
    required this.cityKey,
    this.trueSolarTime = true,
  });

  factory BirthProfile.fromJson(Map<String, dynamic> j) => BirthProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        gender: j['gender'] as String,
        birthLocal: DateTime.parse(j['birth_local'] as String),
        cityKey: j['city'] as String,
        trueSolarTime: j['true_solar_time'] as bool? ?? true,
      );

  final String id;
  final String name;

  /// male | female
  final String gender;

  /// Civil wall-clock time at the birthplace (no time zone).
  final DateTime birthLocal;

  /// Key into [cities] (presentation/bazi_form_page.dart).
  final String cityKey;
  final bool trueSolarTime;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gender': gender,
        'birth_local': birthLocal.toIso8601String(),
        'city': cityKey,
        'true_solar_time': trueSolarTime,
      };

  BirthProfile copyWith({
    String? name,
    String? gender,
    DateTime? birthLocal,
    String? cityKey,
    bool? trueSolarTime,
  }) =>
      BirthProfile(
        id: id,
        name: name ?? this.name,
        gender: gender ?? this.gender,
        birthLocal: birthLocal ?? this.birthLocal,
        cityKey: cityKey ?? this.cityKey,
        trueSolarTime: trueSolarTime ?? this.trueSolarTime,
      );
}

/// Everything kept per account on the device.
class ProfileBook {
  const ProfileBook({this.profiles = const [], this.defaultId, this.chartLabels = const {}});

  factory ProfileBook.decode(String? raw) {
    if (raw == null || raw.isEmpty) return const ProfileBook();
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return ProfileBook(
      profiles: ((j['profiles'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(BirthProfile.fromJson)
          .toList(),
      defaultId: j['default_id'] as String?,
      chartLabels: ((j['chart_labels'] as Map?) ?? const {}).cast<String, String>(),
    );
  }

  final List<BirthProfile> profiles;
  final String? defaultId;

  /// chart_id → profile name, so history can say whose chart it was.
  final Map<String, String> chartLabels;

  BirthProfile? get defaultProfile {
    for (final p in profiles) {
      if (p.id == defaultId) return p;
    }
    return profiles.isEmpty ? null : profiles.first;
  }

  String encode() => jsonEncode({
        'profiles': [for (final p in profiles) p.toJson()],
        'default_id': defaultId,
        'chart_labels': chartLabels,
      });

  ProfileBook copyWith({List<BirthProfile>? profiles, String? defaultId, Map<String, String>? chartLabels}) =>
      ProfileBook(
        profiles: profiles ?? this.profiles,
        defaultId: defaultId ?? this.defaultId,
        chartLabels: chartLabels ?? this.chartLabels,
      );
}
