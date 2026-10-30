import 'dart:convert';

import 'cities.dart';
import 'life_context.dart';
import 'places.dart';

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
    this.ziNextDay = false,
    this.dateMode = 'gregorian',
    this.timeMode = 'exact',
    this.shichen,
    this.place,
    this.life = const LifeContext(),
  });

  /// A new profile's starting values (S28: 个人资料's page and its dialog each had a copy).
  factory BirthProfile.blank() => BirthProfile(
        id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        name: '',
        gender: 'male',
        birthLocal: DateTime(1990, 1, 1, 12),
        cityKey: 'hk',
      );

  factory BirthProfile.fromJson(Map<String, dynamic> j) => BirthProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        gender: j['gender'] as String,
        birthLocal: DateTime.parse(j['birth_local'] as String),
        cityKey: j['city'] as String,
        trueSolarTime: j['true_solar_time'] as bool? ?? true,
        ziNextDay: j['zi_next_day'] as bool? ?? false,
        dateMode: j['date_mode'] as String? ?? 'gregorian',
        timeMode: j['time_mode'] as String? ?? 'exact',
        shichen: j['shichen'] as String?,
        place: j['place'] == null ? null : BirthPlace.fromJson(j['place'] as Map<String, dynamic>),
        life: LifeContext.fromJson(j['life'] as Map<String, dynamic>?),
      );

  final String id;
  final String name;

  /// male | female
  final String gender;

  /// Civil wall-clock time at the birthplace (no time zone).
  final DateTime birthLocal;

  /// Legacy key into [cities]; used only when [place] is null.
  final String cityKey;

  /// Birthplace picked as country → region → city (GET /v1/places).
  final BirthPlace? place;

  /// Personal situation for readings (optional; device only until a report is requested).
  final LifeContext life;

  /// The birthplace in effect: the picked place, else the legacy city.
  BirthPlace get birthPlace => place ?? BirthPlace.legacy(cityByKey(cityKey));
  final bool trueSolarTime;

  /// 子时流派: true = a birth 23:00–24:00 takes the next day's 日柱 (`ziHourSect` 1);
  /// false = the same day (2, the default).
  final bool ziNextDay;

  /// gregorian | lunar — how the date was entered (birthLocal is always 公曆).
  final String dateMode;

  /// exact | shichen — with shichen, birthLocal holds the 時辰 midpoint.
  final String timeMode;

  /// 時辰 key from the server's list: zi_early, 丑 … 亥, zi_late.
  final String? shichen;

  /// The 地支 of [shichen] (早子/晚子 are both 子).
  String? get shichenZhi => shichen == null ? null : (shichen!.startsWith('zi_') ? '子' : shichen);

  Map<String, Object?> get inputBasis => {
        'date': dateMode,
        'time': timeMode,
        if (timeMode == 'shichen' && shichenZhi != null) 'shichen': shichenZhi,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gender': gender,
        'birth_local': birthLocal.toIso8601String(),
        'city': cityKey,
        'true_solar_time': trueSolarTime,
        if (ziNextDay) 'zi_next_day': true,
        'date_mode': dateMode,
        'time_mode': timeMode,
        'shichen': shichen,
        if (place != null) 'place': place!.toJson(),
        if (!life.isEmpty || !life.useName) 'life': life.toJson(),
      };

  BirthProfile copyWith({
    String? name,
    String? gender,
    DateTime? birthLocal,
    String? cityKey,
    bool? trueSolarTime,
    bool? ziNextDay,
    String? dateMode,
    String? timeMode,
    String? shichen,
    BirthPlace? place,
    LifeContext? life,
  }) =>
      BirthProfile(
        id: id,
        name: name ?? this.name,
        gender: gender ?? this.gender,
        birthLocal: birthLocal ?? this.birthLocal,
        cityKey: cityKey ?? this.cityKey,
        trueSolarTime: trueSolarTime ?? this.trueSolarTime,
        ziNextDay: ziNextDay ?? this.ziNextDay,
        dateMode: dateMode ?? this.dateMode,
        timeMode: timeMode ?? this.timeMode,
        shichen: shichen ?? this.shichen,
        place: place ?? this.place,
        life: life ?? this.life,
      );
}

/// Everything kept per account on the device.
class ProfileBook {
  const ProfileBook({this.profiles = const [], this.defaultId, this.chartLabels = const {}, this.chartPlaces = const {}});

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
      chartPlaces: ((j['chart_places'] as Map?) ?? const {}).cast<String, String>(),
    );
  }

  final List<BirthProfile> profiles;
  final String? defaultId;

  /// chart_id → profile name, so history can say whose chart it was.
  final Map<String, String> chartLabels;

  /// chart_id → birthplace label, so reports reopened from history still show it.
  final Map<String, String> chartPlaces;

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
        'chart_places': chartPlaces,
      });

  ProfileBook copyWith({
    List<BirthProfile>? profiles,
    String? defaultId,
    Map<String, String>? chartLabels,
    Map<String, String>? chartPlaces,
  }) =>
      ProfileBook(
        profiles: profiles ?? this.profiles,
        defaultId: defaultId ?? this.defaultId,
        chartLabels: chartLabels ?? this.chartLabels,
        chartPlaces: chartPlaces ?? this.chartPlaces,
      );
}
