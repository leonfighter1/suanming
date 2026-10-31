import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers.dart';
import '../domain/places.dart';
import '../l10n/gen/app_localizations.dart';
import 'buttons.dart';
import 'design.dart';
import 'keyboard.dart';
import 'layout.dart';

/// Countries shown first: launch markets and common birthplaces.
const commonCountries = ['HK', 'MO', 'TW', 'CN', 'SG', 'MY', 'US', 'CA', 'GB', 'AU'];

/// The birthplace field: shows "中國 · 廣東 · 廣州市" and opens [PlacePickerPage].
class PlaceField extends ConsumerWidget {
  const PlaceField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.fieldKey = const Key('city'),
    this.showDetail = true,
    this.onClear,
  });

  /// Null: nothing picked yet (shows "未填寫").
  final BirthPlace? value;
  final ValueChanged<BirthPlace> onChanged;

  /// Defaults to 出生地.
  final String? label;
  final Key fieldKey;

  /// Show timezone + longitude under the field (they drive 真太陽時 for a birthplace).
  final bool showDetail;

  /// Offers a clear button when set and a value is picked.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final v = value;
    return InkWell(
      key: fieldKey,
      borderRadius: BorderRadius.circular(Radii.field),
      onTap: () async {
        final picked = await Navigator.of(context).push<BirthPlace>(
          MaterialPageRoute(builder: (_) => const PlacePickerPage()),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label ?? l10n.city,
          prefixIcon: const Icon(Icons.place_outlined),
          suffixIcon: v != null && onClear != null
              ? AppIconButton(icon: const Icon(Icons.close), onPressed: onClear, tooltip: l10n.lifeNotSet)
              : const Icon(Icons.chevron_right),
          helperText: v != null && showDetail ? l10n.placeDetail(v.timezone, v.longitude.toStringAsFixed(2)) : null,
        ),
        child: Text(
          v?.label(locale) ?? l10n.lifeNotSet,
          key: fieldKey == const Key('city') ? const Key('place-label') : null,
          style: theme.textTheme.bodyLarge?.copyWith(color: v == null ? theme.colorScheme.onSurfaceVariant : null),
        ),
      ),
    );
  }
}

/// 國家和地區 → 省／州 → 城市, each step searchable. Pops the chosen [BirthPlace].
class PlacePickerPage extends ConsumerStatefulWidget {
  const PlacePickerPage({super.key});

  @override
  ConsumerState<PlacePickerPage> createState() => _PlacePickerPageState();
}

class _PlacePickerPageState extends ConsumerState<PlacePickerPage> {
  PlaceCountryInfo? _country;
  PlaceRegion? _region;
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _step(VoidCallback f) => setState(() {
        f();
        _search.clear();
        _q = '';
      });

  bool _back() {
    if (_region != null) {
      _step(() => _region = null);
      return true;
    }
    if (_country != null) {
      _step(() => _country = null);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final title = _region != null
        ? l10n.placeCity
        : _country != null
            ? l10n.placeRegion
            : l10n.placeCountry;
    final crumbs = [_country?.names.of(locale), _region?.names.of(locale)].whereType<String>().join(' · ');

    return PopScope(
      canPop: _country == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.placePick),
          leading: _country == null ? null : BackButton(onPressed: _back),
        ),
        // In the app's container (S27); its rows carry their own inset.
        body: Padding(
          padding: pagePadding(context, top: 0, bottom: 0, margin: false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, 0),
                child: Text(crumbs.isEmpty ? title : '$crumbs · $title', key: const Key('place-step'), style: Theme.of(context).textTheme.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.all(Space.l),
                // Esc clears the search first; with it empty, Esc steps back a level.
                child: Focus(
                  canRequestFocus: false,
                  skipTraversal: true,
                  onKeyEvent: (_, e) {
                    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.escape || _q.isEmpty) {
                      return KeyEventResult.ignored;
                    }
                    _step(() {});
                    return KeyEventResult.handled;
                  },
                  child: TextField(
                    key: const Key('place-search'),
                    controller: _search,
                    // Opened from the keyboard: type at once (no pop-up keyboard after a tap).
                    autofocus: keyboardInUse,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.placeSearch),
                    onChanged: (v) => setState(() => _q = v),
                    // Enter takes the first entry and keeps the focus here for the next step.
                    onEditingComplete: () {},
                    onSubmitted: (_) => _pickFirst(),
                  ),
                ),
              ),
              Expanded(child: _list(context, locale)),
              Padding(
                padding: const EdgeInsets.all(Space.s),
                child: Center(child: Text(l10n.placeSource, style: Theme.of(context).textTheme.bodySmall)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, String locale) {
    final l10n = AppLocalizations.of(context);
    Widget empty() => Center(child: Text(l10n.placeNone));
    Widget loading(AsyncValue<Object?> v, Widget Function() data) => v.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('${l10n.errorTitle}\n$e', textAlign: TextAlign.center)),
          data: (_) => data(),
        );

    if (_country == null) {
      final async = ref.watch(placeCountriesProvider);
      return loading(async, () {
        final (common, all) = _countryList(async.value!);
        if (all.isEmpty) return empty();
        return ListView(
          children: [
            if (common.isNotEmpty) _Header(l10n.placeCommon),
            for (final c in common) _tile(c.names, locale, key: 'country-${c.code}', onTap: () => _pickCountry(c)),
            if (common.isNotEmpty) _Header(l10n.placeAll),
            for (final c in all) _tile(c.names, locale, key: common.contains(c) ? null : 'country-${c.code}', onTap: () => _pickCountry(c)),
          ],
        );
      });
    }

    final async = ref.watch(placeRegionsProvider(_country!.code));
    return loading(async, () {
      final regions = async.value!;
      if (_region == null) {
        // One region only (e.g. small countries): go straight to its cities.
        if (regions.length == 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _region == null) _step(() => _region = regions.first);
          });
          return const SizedBox.shrink();
        }
        final list = _regionList(regions);
        if (list.isEmpty) return empty();
        return ListView(children: [
          for (final r in list) _tile(r.names, locale, key: 'region-${r.code}', trailing: '${r.cities.length}', onTap: () => _step(() => _region = r)),
        ]);
      }
      final cities = _cityList();
      if (cities.isEmpty) return empty();
      return ListView(children: [
        for (final c in cities)
          _tile(
            c.names,
            locale,
            key: 'city-${c.id}',
            subtitle: '${c.timezone} · ${c.longitude.toStringAsFixed(2)}°',
            onTap: () => Navigator.of(context).pop(BirthPlace.pick(_country!, _region!, c)),
          ),
      ]);
    });
  }

  void _pickCountry(PlaceCountryInfo c) => _step(() => _country = c);

  /// Countries as listed: the common ones first (when not searching), then all A–Z.
  (List<PlaceCountryInfo>, List<PlaceCountryInfo>) _countryList(List<PlaceCountryInfo> countries) {
    final all = countries.where((c) => c.names.matches(_q)).toList()..sort((a, b) => a.names.en.compareTo(b.names.en));
    final common = _q.isEmpty ? [for (final code in commonCountries) ...all.where((c) => c.code == code)] : <PlaceCountryInfo>[];
    return (common, all);
  }

  /// A region matches by its own name or any of its cities'.
  List<PlaceRegion> _regionList(List<PlaceRegion> regions) =>
      regions.where((r) => r.names.matches(_q) || r.cities.any((c) => c.names.matches(_q))).toList();

  List<PlaceCity> _cityList() => _region!.cities.where((c) => c.names.matches(_q)).toList();

  /// Enter in the search box: the first entry as listed.
  void _pickFirst() {
    if (_country == null) {
      final countries = ref.read(placeCountriesProvider).value;
      if (countries == null) return;
      final (common, all) = _countryList(countries);
      final first = [...common, ...all].firstOrNull;
      if (first != null) _pickCountry(first);
    } else if (_region == null) {
      final regions = ref.read(placeRegionsProvider(_country!.code)).value;
      final first = regions == null ? null : _regionList(regions).firstOrNull;
      if (first != null) _step(() => _region = first);
    } else {
      final first = _cityList().firstOrNull;
      if (first != null) Navigator.of(context).pop(BirthPlace.pick(_country!, _region!, first));
    }
  }

  Widget _tile(PlaceNames n, String locale, {String? key, String? subtitle, String? trailing, required VoidCallback onTap}) {
    final main = n.of(locale);
    final sub = [if (main != n.en) n.en, ?subtitle].join(' · ');
    return ListTile(
      key: key == null ? null : Key(key),
      title: Text(main),
      subtitle: sub.isEmpty ? null : Text(sub),
      trailing: trailing == null ? const Icon(Icons.chevron_right) : Text(trailing),
      onTap: onTap,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.l, Space.xs),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
