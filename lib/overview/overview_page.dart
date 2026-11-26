// Uebersicht: Wie liefen die letzten sieben Tage? (Konzept 01_navigation_ux.md, 5.1)
// Liest nur Tageswerte aus `daily`, rechnet sie mit PeriodSummary zusammen.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../app/routes.dart';
import '../app/services.dart';
import '../app/session_scope.dart';
import '../charts/chart_basics.dart';
import '../charts/climate_charts.dart';
import '../charts/energy_charts.dart';
import '../charts/info_values.dart';
import '../charts/kpi_tile.dart';
import '../daily/daily_values.dart';
import '../daily/factors.dart';
import '../daily/period.dart';
import '../daily/summary.dart';
import '../household/household.dart';
import '../info/info_texts.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import '../theme/kwf_widgets.dart';
import 'hints.dart';

/// Alles, was Uebersicht und Auswertung laden.
class DailyData {
  const DailyData({
    required this.days,
    required this.household,
    required this.factors,
    this.entries = const [],
  });
  final List<DailyValues> days;
  final List<HouseholdEntry> household;
  final EnergyFactors factors;
  final List<ManualEntry> entries;
}

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  Future<(List<DailyValues>, EnergyFactors, List<ManualEntry>)>? _load;
  String? _loadedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = SessionScope.of(context).active?.id;
    if (id == _loadedFor) return;
    _loadedFor = id;
    if (id == null) return;
    final services = AppServices.of(context);
    final now = services.clock.now();
    // Die letzten sieben Tage, gleich fuer Satz, Kacheln und Balken.
    final week = Period.lastDays(now);
    _load = (
      services.daily.load(id, week.start, dayOf(now)),
      services.factors.load(),
      services.entries.load(id, currentYear: now.year),
    ).wait;
  }

  @override
  Widget build(BuildContext context) {
    final id = _loadedFor;
    if (id == null) return const KwfPage(children: [KwfHint('Kein Monitor gewählt.')]);
    final services = AppServices.of(context);
    return FutureBuilder(
      future: _load,
      builder: (context, snap) => StreamBuilder<List<HouseholdEntry>>(
        stream: services.household.watch(id),
        builder: (context, hh) {
          if (!snap.hasData || !hh.hasData) {
            if (snap.hasError) {
              return const KwfPage(children: [
                KwfPageHeading('Übersicht'),
                KwfHint('Die Tageswerte konnten nicht geladen werden. Versuche es später noch einmal.'),
              ]);
            }
            return const Center(child: CircularProgressIndicator());
          }
          final (days, factors, entries) = snap.data!;
          return OverviewView(
            data: DailyData(days: days, household: hh.data!, factors: factors, entries: entries),
            now: services.clock.now(),
          );
        },
      ),
    );
  }
}

/// Inhalt der Uebersicht ohne Laden, fuer Tests direkt renderbar.
class OverviewView extends StatelessWidget {
  const OverviewView({super.key, required this.data, required this.now});
  final DailyData data;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final week = Period.lastDays(now);
    final s = PeriodSummary.of(
        period: week, days: data.days, household: data.household, factors: data.factors);
    final values = infoValues(s, data.factors);
    final stand = standText(s.dataUntil);
    final hints = overviewHints(entries: data.entries, days: data.days, now: now);

    if (data.days.isEmpty) {
      return KwfPage(children: [
        const KwfPageHeading('Übersicht'),
        KwfCard(
          padding: const EdgeInsets.all(20),
          child: Text(
              'Die ersten Tageswerte kommen nach der ersten vollen Stunde mit Daten. '
              'Danach siehst du hier, wie viel Energie ihr in den letzten sieben Tagen gebraucht habt und woher '
              'sie kam.',
              style: KwfText.body),
        ),
      ]);
    }

    return KwfPage(children: [
      _WeekSentence(summary: s, now: now),
      if (data.household.isEmpty) const PersonsMissingWarning(),
      _Tiles(summary: s, data: data, now: now, values: values, stand: stand),
      ChartCard(
        title: 'Wofür ging die Energie drauf?',
        subtitle: 'kWh pro Tag, ${week.label}',
        info: InfoTexts.dailyBars,
        stand: stand,
        child: WeekBars(summary: s),
      ),
      for (final h in hints) _HintBox(h),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const ValueKey('to-analysis'),
          onPressed: () => context.go(Routes.analysis),
          icon: const Icon(Icons.bar_chart, size: 18),
          label: const Text('Zur Auswertung'),
        ),
      ),
    ]);
  }
}

class _WeekSentence extends StatelessWidget {
  const _WeekSentence({required this.summary, required this.now});
  final PeriodSummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final until = s.dataUntil;
    final String sentence;
    if (s.totalKwh < 0.5) {
      sentence = 'Noch kaum Daten in den letzten sieben Tagen. Die Tageswerte kommen jede Stunde.';
    } else {
      final solar = s.totalKwh > 0 ? s.pvSelfKwh / s.totalKwh : 0.0;
      sentence = 'In den letzten sieben Tagen habt ihr ${fmtKwh(s.totalKwh)} kWh gebraucht'
          '${s.hasPv ? ', ${fmtPct(solar)} davon von der Sonne' : ''}.';
    }
    final meta = [
      '${DateFormat('EEEE', 'de').format(s.period.start)} bis ${until == null ? 'heute' : (dayOf(until) == dayOf(now) ? 'heute ${DateFormat('HH:mm').format(until)}' : DateFormat('EEEE HH:mm', 'de').format(until))}',
      if (s.personsNow != null) s.personsNow == 1 ? '1 Person' : '${s.personsNow} Personen',
      if (s.fuelEstimated) 'Brennstoffe geschätzt',
      if (s.gappyDays > 0) 'Daten lückenhaft (${s.gappyDays} ${s.gappyDays == 1 ? 'Tag' : 'Tage'})',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KwfKicker('Letzte 7 Tage'),
        const SizedBox(height: 6),
        Semantics(header: true, child: Text(sentence, style: kwfText(22, height: 1.25))),
        const SizedBox(height: 6),
        Text(meta, style: KwfText.meta),
      ],
    );
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles(
      {required this.summary,
      required this.data,
      required this.now,
      required this.values,
      required this.stand});
  final PeriodSummary summary;
  final DailyData data;
  final DateTime now;
  final Map<String, String> values;
  final String stand;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    // Verlauf der letzten sieben Tage (bis heute).
    final days = [for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i)];
    final byDay = {for (final d in data.days) d.date: d};
    List<double?> series(double? Function(PeriodSummary) f) => [
          for (final d in days)
            if (byDay[d] case final v?)
              f(PeriodSummary.of(
                  period: Period.of(RangeKind.week, d, today: now),
                  days: [v],
                  household: data.household,
                  factors: data.factors))
            else
              null,
        ];

    final tiles = <Widget>[
      KpiTile(
        label: 'Verbrauch pro Person und Tag',
        value: s.kwhPerPersonDay == null ? '–' : fmtNum(s.kwhPerPersonDay!, digits: 1),
        unit: 'kWh',
        color: KwfColors.dataVerbrauch,
        spark: series((x) => x.kwhPerPersonDay),
        context: s.householdMissing && s.personsNow == null
            ? 'Personen fehlen: unter Mehr > Haushalt eintragen.'
            : 'Letzte 7 Tage',
        info: InfoTexts.consumptionPerPerson.fill(values),
        stand: stand,
      ),
      KpiTile(
        label: 'Eigenversorgung Strom',
        value: s.autarky == null || !s.hasPv ? '–' : fmtNum(s.autarky! * 100, digits: 0),
        unit: '%',
        color: KwfColors.dataSolar,
        spark: series((x) => x.autarky == null ? null : x.autarky! * 100),
        context: s.hasPv ? 'Strom von der eigenen Sonne' : 'Keine Solaranlage gemessen',
        info: InfoTexts.autarky,
        stand: stand,
      ),
      if (s.tInMedian != null)
        KpiTile(
          label: 'Wohnklima innen',
          value: fmtNum(s.tInMedian!, digits: 1),
          unit: '°C',
          color: KwfColors.klimaInnen,
          spark: series((x) => x.tInMedian),
          trailing: ComfortBadge(temperatureLevel(s.tInMedian!),
              temperatureWord(temperatureLevel(s.tInMedian!))),
          context: s.occupiedDays > 0 ? 'Median an bewohnten Tagen' : 'Median',
          info: InfoTexts.climate,
          stand: stand,
        ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }
}

/// Tagesbalken der letzten sieben Tage, heute rechts. Brennstoffe, die nicht auf
/// Tage verteilt werden koennen, stehen als Summe darunter.
class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.summary});
  final PeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final byDate = {for (final d in s.days) d.date: d};
    final p = s.period;
    final spread = [for (final f in s.fuels.values) if (f.evenlySpread) f];
    final spreadCarriers = {for (final f in spread) ?Carrier.ofFuel(f.type)};
    final bars = <BarValue>[
      for (var i = 0; i < 7; i++)
        () {
          final date = DateTime(p.start.year, p.start.month, p.start.day + i);
          final d = byDate[date];
          if (d == null) return BarValue(date, const {}, note: date.isAfter(p.today) ? null : 'keine Daten');
          return BarValue(
            date,
            {
              for (final e in d.kwh.entries)
                if (!spreadCarriers.contains(e.key)) e.key: e.value,
            },
            estimated: d.estimated,
            note: d.gappy ? 'Daten lückenhaft' : (d.partial ? 'heute bis jetzt' : null),
          );
        }(),
    ];
    final carriers = {for (final b in bars) ...b.kwh.keys};
    final estimated = {for (final b in bars) ...b.estimated};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (carriers.isNotEmpty) ChartLegend(carriers: carriers, estimated: estimated),
        const SizedBox(height: 10),
        StackedBars(
          bars: bars,
          labelOf: (d) => kDayLabel.format(d).substring(0, 2),
          tooltipDate: (d) => kDayDate.format(d),
        ),
        for (final f in spread)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${kFuelLabels[f.type] ?? f.type}: ${f.kwh == null ? '' : '${fmtKwh(f.kwh!)} kWh '}'
              'in den letzten sieben Tagen, geschätzt. Verteilung auf Tage nicht möglich (kein Klimasensor).',
              style: KwfText.small,
            ),
          ),
        for (final t in s.unknownFuels)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${kFuelLabels[t] ?? t}: ${(s.fuels[t]?.fires ?? 0) > 0 ? '${s.fuels[t]!.fires} Feuer erkannt, ' : ''}'
              'die Menge kennen wir erst mit dem nächsten Eintrag.',
              style: KwfText.small,
            ),
          ),
      ],
    );
  }
}

class _HintBox extends StatelessWidget {
  const _HintBox(this.hint);
  final OverviewHint hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KwfColors.hellblau,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lightbulb_outline, size: 20, color: KwfColors.anthrazit),
            const SizedBox(width: 10),
            Expanded(child: Text(hint.text, style: KwfText.small)),
          ]),
          if (hint.action != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => switch (hint.target) {
                  HintTarget.capture => context.go(Routes.capture),
                  HintTarget.schema => context.push(Routes.measurementSchema),
                  HintTarget.none => null,
                },
                child: Text(hint.action!),
              ),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}
