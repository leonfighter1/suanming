import 'cities.dart';
import 'models.dart' show Json;

/// A place name in the three app languages (GET /v1/places…).
class PlaceNames {
  const PlaceNames(this.zhHant, this.zhHans, this.en);
  factory PlaceNames.fromJson(Json j) => PlaceNames(j['zh-Hant'] as String, j['zh-Hans'] as String, j['en'] as String);
  final String zhHant;
  final String zhHans;
  final String en;

  String of(String apiLocale) => switch (apiLocale) {
        'zh-Hant' => zhHant,
        'zh-Hans' => zhHans,
        _ => en,
      };

  /// Search matches any language, case-insensitively.
  bool matches(String q) {
    final s = q.trim().toLowerCase();
    return s.isEmpty || zhHant.contains(s) || zhHans.contains(s) || en.toLowerCase().contains(s);
  }

  Json toJson() => {'zh-Hant': zhHant, 'zh-Hans': zhHans, 'en': en};
}

class PlaceCountryInfo {
  const PlaceCountryInfo(this.code, this.names, this.cities);
  factory PlaceCountryInfo.fromJson(Json j) =>
      PlaceCountryInfo(j['code'] as String, PlaceNames.fromJson(j['names'] as Json), j['cities'] as int);
  final String code;
  final PlaceNames names;
  final int cities;
}

class PlaceCity {
  const PlaceCity(this.id, this.names, this.timezone, this.longitude);
  factory PlaceCity.fromJson(Json j) =>
      PlaceCity(j['id'] as int, PlaceNames.fromJson(j['names'] as Json), j['tz'] as String, (j['lon'] as num).toDouble());
  final int id;
  final PlaceNames names;
  final String timezone;
  final double longitude;
}

class PlaceRegion {
  const PlaceRegion(this.code, this.names, this.cities);
  factory PlaceRegion.fromJson(Json j) => PlaceRegion(
        j['code'] as String,
        PlaceNames.fromJson(j['names'] as Json),
        (j['cities'] as List).cast<Json>().map(PlaceCity.fromJson).toList(),
      );
  final String code;
  final PlaceNames names;
  final List<PlaceCity> cities;
}

/// A chosen birthplace: country → region → city. Timezone drives historical DST,
/// longitude drives 真太陽時.
class BirthPlace {
  const BirthPlace({
    required this.country,
    required this.city,
    required this.timezone,
    required this.longitude,
    this.countryNames,
    this.region,
    this.regionNames,
    this.cityId,
  });

  factory BirthPlace.fromJson(Json j) => BirthPlace(
        country: j['country'] as String,
        countryNames: j['country_names'] == null ? null : PlaceNames.fromJson(j['country_names'] as Json),
        region: j['region'] as String?,
        regionNames: j['region_names'] == null ? null : PlaceNames.fromJson(j['region_names'] as Json),
        cityId: j['city_id'] as int?,
        city: PlaceNames.fromJson(j['city'] as Json),
        timezone: j['tz'] as String,
        longitude: (j['lon'] as num).toDouble(),
      );

  factory BirthPlace.pick(PlaceCountryInfo c, PlaceRegion r, PlaceCity city) => BirthPlace(
        country: c.code,
        countryNames: c.names,
        region: r.code,
        regionNames: r.names,
        cityId: city.id,
        city: city.names,
        timezone: city.timezone,
        longitude: city.longitude,
      );

  /// Profiles saved before the place picker only had a city key.
  factory BirthPlace.legacy(City c) => BirthPlace(
        country: c.country,
        city: PlaceNames(c.names['zh-Hant']!, c.names['zh-Hans']!, c.names['en']!),
        timezone: c.timezone,
        longitude: c.longitude,
      );

  final String country;
  final PlaceNames? countryNames;
  final String? region;
  final PlaceNames? regionNames;
  final int? cityId;
  final PlaceNames city;
  final String timezone;
  final double longitude;

  /// "中國 · 廣東 · 廣州市" (parts that are known).
  String label(String apiLocale) => [
        countryNames?.of(apiLocale),
        // City-states repeat the country as the region; skip it.
        if (regionNames != null && regionNames!.of(apiLocale) != countryNames?.of(apiLocale)) regionNames!.of(apiLocale),
        city.of(apiLocale),
      ].whereType<String>().join(' · ');

  Json toJson() => {
        'country': country,
        if (countryNames != null) 'country_names': countryNames!.toJson(),
        if (region != null) 'region': region,
        if (regionNames != null) 'region_names': regionNames!.toJson(),
        if (cityId != null) 'city_id': cityId,
        'city': city.toJson(),
        'tz': timezone,
        'lon': longitude,
      };
}
