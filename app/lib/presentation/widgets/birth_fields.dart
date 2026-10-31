import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers.dart';
import '../../domain/models.dart';
import '../../domain/profile.dart';
import '../../l10n/gen/app_localizations.dart';
import '../buttons.dart';
import '../design.dart';
import '../keyboard.dart';
import '../place_picker.dart';

/// Birth date/time, place, gender and 真太陽時 — shared by the profile editor
/// and the 八字 form. Shows the 農曆 equivalent of the chosen date live.
class BirthFields extends ConsumerWidget {
  const BirthFields({super.key, required this.value, required this.onChanged});
  final BirthProfile value;
  final ValueChanged<BirthProfile> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final d = value.birthLocal;
    final lunarMode = value.dateMode == 'lunar';
    final shichenMode = value.timeMode == 'shichen';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.birthTime, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: Space.s),
        // Date: 公曆 or 農曆 (birthLocal is always stored as 公曆).
        SegmentKeys(
          child: SegmentedButton<String>(
            key: const Key('date-mode'),
            segments: [
              ButtonSegment(value: 'gregorian', label: Text(l10n.gregorian), icon: const Icon(Icons.calendar_today, size: 18)),
              ButtonSegment(value: 'lunar', label: Text(l10n.lunarLabel), icon: const Icon(Icons.nightlight_round, size: 18)),
            ],
            selected: {value.dateMode},
            onSelectionChanged: (s) => onChanged(value.copyWith(dateMode: s.first)),
          ),
        ),
        const SizedBox(height: Space.s),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: lunarMode
              ? LunarDatePicker(key: const ValueKey('lunar'), value: value, onChanged: onChanged)
              : AppOutlinedButton.icon(
                  key: const ValueKey('gregorian'),
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(DateFormat('yyyy-MM-dd').format(d)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: d,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      // From the keyboard: type the date instead of arrowing back through the years.
                      initialEntryMode: keyboardInUse ? DatePickerEntryMode.input : DatePickerEntryMode.calendar,
                    );
                    if (picked != null) {
                      onChanged(value.copyWith(birthLocal: DateTime(picked.year, picked.month, picked.day, d.hour, d.minute)));
                    }
                  },
                ),
        ),
        const SizedBox(height: Space.s),
        // Shows the other calendar: 農曆 when picking 公曆, and the 公曆 date in 農曆 mode.
        lunarMode
            ? Align(
                alignment: Alignment.centerLeft,
                child: Pill('${l10n.gregorian} ${DateFormat('yyyy-MM-dd').format(d)}', icon: Icons.calendar_today),
              )
            : LunarPreview(date: d),
        const SizedBox(height: Space.l),
        // Time: exact clock time, or a 時辰 with its 干支.
        SegmentKeys(
          child: SegmentedButton<String>(
            key: const Key('time-mode'),
            segments: [
              ButtonSegment(value: 'exact', label: Text(l10n.timeExact), icon: const Icon(Icons.schedule, size: 18)),
              ButtonSegment(value: 'shichen', label: Text(l10n.timeShichen), icon: const Icon(Icons.hourglass_bottom, size: 18)),
            ],
            selected: {value.timeMode},
            onSelectionChanged: (s) {
              if (s.first == 'exact') return onChanged(value.copyWith(timeMode: 'exact'));
              // Start from the 時辰 that contains the current time.
              final key = shichenKeyFor(d.hour);
              onChanged(value.copyWith(timeMode: 'shichen', shichen: key, birthLocal: _withMid(d, key)));
            },
          ),
        ),
        const SizedBox(height: Space.s),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: shichenMode
              ? ShichenPicker(key: const ValueKey('shichen'), value: value, onChanged: onChanged)
              : AppOutlinedButton.icon(
                  key: const ValueKey('exact'),
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(TimeOfDay.fromDateTime(d).format(context)),
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(d),
                      initialEntryMode: keyboardInUse ? TimePickerEntryMode.input : TimePickerEntryMode.dial,
                    );
                    if (t != null) onChanged(value.copyWith(birthLocal: DateTime(d.year, d.month, d.day, t.hour, t.minute)));
                  },
                ),
        ),
        const SizedBox(height: Space.l),
        // Country/region → province/state → city (timezone + longitude for 真太陽時).
        PlaceField(value: value.birthPlace, onChanged: (p) => onChanged(value.copyWith(place: p))),
        const SizedBox(height: Space.l),
        Text(l10n.gender, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: Space.s),
        SegmentKeys(
          child: SegmentedButton<String>(
            key: const Key('gender'),
            segments: [
              ButtonSegment(value: 'male', label: Text(l10n.male), icon: const Icon(Icons.male)),
              ButtonSegment(value: 'female', label: Text(l10n.female), icon: const Icon(Icons.female)),
            ],
            selected: {value.gender},
            onSelectionChanged: (s) => onChanged(value.copyWith(gender: s.first)),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.trueSolarTime),
          value: value.trueSolarTime,
          onChanged: (v) => onChanged(value.copyWith(trueSolarTime: v)),
        ),
        SwitchListTile(
          key: const Key('zi-next-day'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.ziNextDay),
          subtitle: Text(l10n.ziNextDayHint),
          value: value.ziNextDay,
          onChanged: (v) => onChanged(value.copyWith(ziNextDay: v)),
        ),
      ],
    );
  }
}

/// The 時辰 key containing a clock hour: 0 → 早子, 23 → 晚子, else 丑 … 亥.
String shichenKeyFor(int hour) {
  if (hour == 0) return 'zi_early';
  if (hour == 23) return 'zi_late';
  return '子丑寅卯辰巳午未申酉戌亥'[(hour + 1) ~/ 2];
}

/// Midpoint the server uses for each 時辰 (00:30, 02:00 … 22:00, 23:30).
DateTime _withMid(DateTime d, String key) {
  final (h, m) = switch (key) {
    'zi_early' => (0, 30),
    'zi_late' => (23, 30),
    _ => ('子丑寅卯辰巳午未申酉戌亥'.indexOf(key) * 2, 0),
  };
  return DateTime(d.year, d.month, d.day, h, m);
}

const _dayNames = [
  '初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十',
  '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
  '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十',
];

/// 農曆 year / month (incl. 閏月) / day. Each change converts to 公曆 on the server.
class LunarDatePicker extends ConsumerWidget {
  const LunarDatePicker({super.key, required this.value, required this.onChanged});
  final BirthProfile value;
  final ValueChanged<BirthProfile> onChanged;

  Future<void> _set(WidgetRef ref, int year, int month, bool leap, int day) async {
    final d = value.birthLocal;
    final solar = await ref.read(apiClientProvider).lunarToSolar(year, month, day, leap: leap);
    onChanged(value.copyWith(dateMode: 'lunar', birthLocal: DateTime(solar.year, solar.month, solar.day, d.hour, d.minute)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final terms = ref.watch(termsProvider).value;
    String chars(String s) => s.characters.map((c) => terms?.t(c, locale) ?? c).join();
    final current = ref.watch(calendarDayProvider(value.birthLocal)).value?.lunar;
    if (current == null) return const SizedBox(height: 56, child: Center(child: LinearProgressIndicator()));
    final months = ref.watch(lunarMonthsProvider(current.year)).value ?? const <LunarMonthInfo>[];
    final monthKey = '${current.month}${current.isLeapMonth ? 'L' : ''}';
    final monthInfo = months.where((m) => '${m.month}${m.isLeap ? 'L' : ''}' == monthKey).firstOrNull;

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: DropdownMenu<int>(
            key: const Key('lunar-year'),
            expandedInsets: EdgeInsets.zero,
            label: Text(l10n.lunarYear),
            initialSelection: current.year,
            menuHeight: 320,
            dropdownMenuEntries: [
              for (var y = DateTime.now().year; y >= 1900; y--) DropdownMenuEntry(value: y, label: '$y'),
            ],
            // Keep month and day; fall back to 正月 when the year lacks this (leap) month.
            onSelected: (y) async {
              if (y == null) return;
              final ms = await ref.read(lunarMonthsProvider(y).future);
              final m = ms.where((m) => m.month == current.month && m.isLeap == current.isLeapMonth).firstOrNull ?? ms.first;
              await _set(ref, y, m.month, m.isLeap, current.day.clamp(1, m.days));
            },
          ),
        ),
        const SizedBox(width: Space.s),
        Expanded(
          flex: 5,
          child: DropdownMenu<String>(
            key: ValueKey('lunar-month-${current.year}'),
            expandedInsets: EdgeInsets.zero,
            label: Text(l10n.lunarMonth),
            initialSelection: monthKey,
            dropdownMenuEntries: [
              for (final m in months) DropdownMenuEntry(value: '${m.month}${m.isLeap ? 'L' : ''}', label: chars(m.name)),
            ],
            onSelected: (k) {
              final m = months.where((m) => '${m.month}${m.isLeap ? 'L' : ''}' == k).firstOrNull;
              if (m != null) _set(ref, current.year, m.month, m.isLeap, current.day.clamp(1, m.days));
            },
          ),
        ),
        const SizedBox(width: Space.s),
        Expanded(
          flex: 4,
          child: DropdownMenu<int>(
            key: ValueKey('lunar-day-$monthKey-${current.year}'),
            expandedInsets: EdgeInsets.zero,
            label: Text(l10n.lunarDay),
            initialSelection: current.day,
            menuHeight: 320,
            dropdownMenuEntries: [
              for (var i = 1; i <= (monthInfo?.days ?? 30); i++) DropdownMenuEntry(value: i, label: _dayNames[i - 1]),
            ],
            onSelected: (day) => day == null || monthInfo == null
                ? null
                : _set(ref, current.year, monthInfo.month, monthInfo.isLeap, day),
          ),
        ),
      ],
    );
  }
}

/// The day's 時辰 as chips: 干支 + clock range. Picking one sets the time to its midpoint.
class ShichenPicker extends ConsumerWidget {
  const ShichenPicker({super.key, required this.value, required this.onChanged});
  final BirthProfile value;
  final ValueChanged<BirthProfile> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final terms = ref.watch(termsProvider).value;
    final options = ref.watch(calendarDayProvider(value.birthLocal)).value?.shichen ?? const <ShichenOption>[];
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            for (final o in options)
              ChoiceChip(
                key: Key('shichen-${o.key}'),
                selected: value.shichen == o.key,
                showCheckmark: false,
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${o.ganzhi}${terms?.t('时', locale) ?? '時'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${o.start}–${o.end}', style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
                onSelected: (_) {
                  final d = value.birthLocal;
                  onChanged(value.copyWith(
                    timeMode: 'shichen',
                    shichen: o.key,
                    birthLocal: DateTime(d.year, d.month, d.day, o.midHour, o.midMinute),
                  ));
                },
              ),
          ],
        ),
        const SizedBox(height: Space.s),
        Text(l10n.shichenNote, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

/// 「農曆 庚午年二月十九（生肖馬）」 for a date, fading between values.
class LunarPreview extends ConsumerWidget {
  const LunarPreview({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).apiLocaleCode;
    final terms = ref.watch(termsProvider).value;
    final lunar = ref.watch(calendarDayProvider(DateTime(date.year, date.month, date.day))).value?.lunar;
    String chars(String s) => s.characters.map((c) => terms?.t(c, locale) ?? c).join();
    final text = lunar == null
        ? ''
        : '${l10n.lunarLabel} ${lunar.yearGanzhi}年${chars(lunar.monthName)}${lunar.dayName}（${l10n.zodiac}${terms?.t(lunar.shengxiao, locale) ?? lunar.shengxiao}）';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: text.isEmpty
          // As tall as the pill that takes its place: its 16-point line and 4 above and below.
          ? const SizedBox(height: Space.xl)
          : Align(
              key: ValueKey(text),
              alignment: Alignment.centerLeft,
              child: Pill(text, icon: Icons.nightlight_round),
            ),
    );
  }
}
