import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/providers.dart';
import '../l10n/gen/app_localizations.dart';
import 'bazi_chart_page.dart';

class City {
  const City(this.names, this.timezone, this.longitude);
  final Map<String, String> names;
  final String timezone;
  final double longitude;
  String name(String apiLocale) => names[apiLocale] ?? names['en']!;
}

/// Launch-market birthplaces. Longitude drives 真太陽時; timezone drives historical DST.
const cities = [
  City({'zh-Hant': '香港', 'zh-Hans': '香港', 'en': 'Hong Kong'}, 'Asia/Hong_Kong', 114.1694),
  City({'zh-Hant': '台北', 'zh-Hans': '台北', 'en': 'Taipei'}, 'Asia/Taipei', 121.5654),
  City({'zh-Hant': '新加坡', 'zh-Hans': '新加坡', 'en': 'Singapore'}, 'Asia/Singapore', 103.8198),
  City({'zh-Hant': '吉隆坡', 'zh-Hans': '吉隆坡', 'en': 'Kuala Lumpur'}, 'Asia/Kuala_Lumpur', 101.6869),
  City({'zh-Hant': '上海', 'zh-Hans': '上海', 'en': 'Shanghai'}, 'Asia/Shanghai', 121.4737),
  City({'zh-Hant': '廣州', 'zh-Hans': '广州', 'en': 'Guangzhou'}, 'Asia/Shanghai', 113.2644),
  City({'zh-Hant': '紐約', 'zh-Hans': '纽约', 'en': 'New York'}, 'America/New_York', -74.006),
  City({'zh-Hant': '溫哥華', 'zh-Hans': '温哥华', 'en': 'Vancouver'}, 'America/Vancouver', -123.1207),
  City({'zh-Hant': '多倫多', 'zh-Hans': '多伦多', 'en': 'Toronto'}, 'America/Toronto', -79.3832),
  City({'zh-Hant': '倫敦', 'zh-Hans': '伦敦', 'en': 'London'}, 'Europe/London', -0.1278),
  City({'zh-Hant': '悉尼', 'zh-Hans': '悉尼', 'en': 'Sydney'}, 'Australia/Sydney', 151.2093),
];

class BaziFormPage extends ConsumerStatefulWidget {
  const BaziFormPage({super.key});

  @override
  ConsumerState<BaziFormPage> createState() => _BaziFormPageState();
}

class _BaziFormPageState extends ConsumerState<BaziFormPage> {
  DateTime _date = DateTime(1990, 3, 15);
  TimeOfDay _time = const TimeOfDay(hour: 14, minute: 30);
  City _city = cities.first;
  String _gender = 'male';
  bool _trueSolar = true;
  bool _busy = false;

  String get _local =>
      '${DateFormat('yyyy-MM-dd').format(_date)}T${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final chart = await ref.read(apiClientProvider).createChart({
        'system': 'bazi',
        'local': _local,
        'timezone': _city.timezone,
        'longitude': _city.longitude,
        'gender': _gender,
        'options': {'trueSolarTime': _trueSolar},
      });
      await navigator.push(MaterialPageRoute<void>(builder: (_) => BaziChartPage(chart: chart)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeBazi)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.birthTime, style: Theme.of(context).textTheme.labelLarge),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('yyyy-MM-dd').format(_date)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(_time.format(context)),
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _time);
                    if (t != null) setState(() => _time = t);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<City>(
            initialValue: _city,
            decoration: InputDecoration(labelText: l10n.city),
            items: [for (final c in cities) DropdownMenuItem(value: c, child: Text(c.name(locale)))],
            onChanged: (c) => setState(() => _city = c ?? _city),
          ),
          const SizedBox(height: 16),
          Text(l10n.gender, style: Theme.of(context).textTheme.labelLarge),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'male', label: Text(l10n.male)),
              ButtonSegment(value: 'female', label: Text(l10n.female)),
            ],
            selected: {_gender},
            onSelectionChanged: (s) => setState(() => _gender = s.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.trueSolarTime),
            value: _trueSolar,
            onChanged: (v) => setState(() => _trueSolar = v),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('compute-chart'),
            onPressed: _busy ? null : _submit,
            child: Text(l10n.compute),
          ),
        ],
      ),
    );
  }
}
