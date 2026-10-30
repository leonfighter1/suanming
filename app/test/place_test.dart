import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/data/profile_store.dart';
import 'package:mingli_app/domain/places.dart';
import 'package:mingli_app/domain/profile.dart';

import 'keys.dart';
import 'support.dart';

void main() {
  testWidgets('birthplace: country → province → city, and the chart uses its timezone and longitude', (tester) async {
    final api = FakeApi(email: 'test@mingli.local');
    await tester.pumpWidget(testApp(api, profiles: InMemoryProfileStore()));
    await frames(tester, 12);
    await tester.tap(find.byKey(const Key('entry-bazi')));
    await frames(tester, 12);

    await scrollAndTap(tester, find.byKey(const Key('city')), after: true);
    expect(find.text('國家和地區'), findsOneWidget);
    // Common countries first; 中國 → (廣東) → 廣州市.
    await tester.tap(find.byKey(const Key('country-CN')).first);
    await frames(tester, 12);
    // The fixture trims 中國 to one region (廣東), so the picker goes straight to its cities.
    expect(find.textContaining('中國 · 廣東 · 城市'), findsOneWidget);
    expect(find.textContaining('Asia/Shanghai · 113.25°'), findsWidgets);
    await tester.tap(find.byKey(const Key('city-1809858')));
    await frames(tester, 12);

    expect(find.text('中國 · 廣東 · 廣州市'), findsOneWidget);
    expect(find.textContaining('Asia/Shanghai'), findsOneWidget);
    await scrollAndTap(tester, find.byKey(const Key('compute-chart')), after: true);
    final body = jsonDecode(api.requests.lastWhere((r) => r.url.path == '/v1/charts').body) as Map;
    expect(body['timezone'], 'Asia/Shanghai');
    expect(body['longitude'], 113.25);
  });

  testWidgets('birthplace search works in any language, and back returns to the previous step', (tester) async {
    final api = FakeApi(email: 'test@mingli.local');
    await tester.pumpWidget(testApp(api, profiles: InMemoryProfileStore()));
    await frames(tester, 12);
    await tester.tap(find.byKey(const Key('entry-bazi')));
    await frames(tester, 12);
    await scrollAndTap(tester, find.byKey(const Key('city')), after: true);

    await tester.enterText(find.byKey(const Key('place-search')), 'hong');
    await frames(tester, 12);
    expect(find.text('香港'), findsOneWidget);
    expect(find.text('中國'), findsNothing);
    await tester.tap(find.text('香港'));
    await frames(tester, 12);
    // Search field clears per step; 沙田 matches its district.
    await tester.enterText(find.byKey(const Key('place-search')), '沙田');
    await frames(tester, 12);
    expect(find.text('沙田區'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await frames(tester, 12);
    expect(find.text('國家和地區'), findsOneWidget);
  });

  test('profiles saved before the picker still compute (legacy city key)', () {
    final p = BirthProfile.fromJson({
      'id': 'x',
      'name': 'a',
      'gender': 'male',
      'birth_local': '1990-03-15T14:30:00.000',
      'city': 'taipei',
    });
    expect(p.place, isNull);
    expect(p.birthPlace.timezone, 'Asia/Taipei');
    expect(p.birthPlace.longitude, closeTo(121.5654, 1e-6));
    expect(p.birthPlace.label('zh-Hant'), '台北');
  });

  test('a picked place survives the round trip through storage', () {
    const place = BirthPlace(
      country: 'CN',
      countryNames: PlaceNames('中國', '中国', 'China'),
      region: '30',
      regionNames: PlaceNames('廣東', '广东', 'Guangdong'),
      cityId: 1809858,
      city: PlaceNames('廣州市', '广州市', 'Guangzhou'),
      timezone: 'Asia/Shanghai',
      longitude: 113.25,
    );
    final p = BirthProfile(id: 'x', name: 'a', gender: 'male', birthLocal: DateTime(1990), cityKey: 'hk', place: place);
    final back = BirthProfile.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(back.birthPlace.label('zh-Hans'), '中国 · 广东 · 广州市');
    expect(back.birthPlace.timezone, 'Asia/Shanghai');
    expect(back.birthPlace.cityId, 1809858);
  });
}
