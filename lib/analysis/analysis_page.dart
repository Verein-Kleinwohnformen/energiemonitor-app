// Auswertung: Wie stehen wir im Vergleich da? (Konzept 01_navigation_ux.md, 5.2)
// Ein Zeitraum-Umschalter oben, alle Abschnitte folgen ihm.
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
import '../info/info_overlay.dart';
import '../info/info_texts.dart';
import '../overview/overview_page.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_widgets.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  String? _loadedFor;
  Period? _period;
  Future<(List<DailyValues>, EnergyFactors)>? _load;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = SessionScope.of(context).active?.id;
    if (id == _loadedFor) return;
    _loadedFor = id;
    _period = null;
    if (id == null) return;
    final services = AppServices.of(context);
    final now = services.clock.now();
    // Zuerst das Jahr: so steht fest, ob es schon 12 Monate Daten gibt.
    final year = Period.of(RangeKind.year, now, today: now);
    _load = (services.daily.load(id, year.start, year.until), services.factors.load()).wait
        .then((r) {
      if (mounted && _period == null) {
        setState(() => _period = defaultPeriod(r.$1, now));
      }
      return r;
    });
  }

  void _select(Period p) {
    final id = _loadedFor;
    if (id == null) return;
    final services = AppServices.of(context);
    setState(() {
      _period = p;
      _load = (services.daily.load(id, p.start, p.until), services.factors.load()).wait;
    });
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
          if (snap.hasError) {
            return const KwfPage(children: [
              KwfPageHeading('Auswertung'),
              KwfHint('Die Tageswerte konnten nicht geladen werden. Versuche es später noch einmal.'),
            ]);
          }
          final period = _period;
          if (!snap.hasData || !hh.hasData || period == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final (days, factors) = snap.data!;
          return AnalysisView(
            period: period,
            data: DailyData(days: days, household: hh.data!, factors: factors),
            onPeriod: _select,
          );
        },
      ),
    );
  }
}

/// Standard: Jahr, sobald 12 Monate Daten da sind, sonst Saison bis jetzt.
/// TODO(prüfen): "12 Monate Daten" heisst hier: Daten ab der ersten Woche des
/// Jahreszeitraums und an mindestens 300 Tagen.
Period defaultPeriod(List<DailyValues> yearDays, DateTime now) {
  final year = Period.of(RangeKind.year, now, today: now);
  final full = yearDays.length >= 300 &&
      yearDays
          .map((d) => d.date)
          .reduce((a, b) => a.isBefore(b) ? a : b)
          .isBefore(DateTime(year.start.year, year.start.month, year.start.day + 7));
  return full ? year : Period.of(RangeKind.season, now, today: now);
}

/// Inhalt der Auswertung ohne Laden, fuer Tests direkt renderbar.
class AnalysisView extends StatefulWidget {
  const AnalysisView({super.key, required this.period, required this.data, this.onPeriod});
  final Period period;
  final DailyData data;
  final ValueChanged<Period>? onPeriod;

  @override
  State<AnalysisView> createState() => _AnalysisViewState();
}

class _AnalysisViewState extends State<AnalysisView> {
  bool _withPv = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.period;
    final d = widget.data;
    final s = PeriodSummary.of(period: p, days: d.days, household: d.household, factors: d.factors);
    final values = infoValues(s, d.factors);
    final stand = standText(s.dataUntil);
    final short = p.kind == RangeKind.week || p.kind == RangeKind.month;
    final hasClimate = s.climateDays > 0;

    return KwfPage(children: [
      const KwfPageHeading('Auswertung'),
      RangeSwitch(period: p, onChanged: (n) => widget.onPeriod?.call(n)),
      _DataNote(summary: s),
      if (s.daysWithData == 0)
        const KwfCard(
          padding: EdgeInsets.all(16),
          child: ChartEmpty('Für diesen Zeitraum gibt es noch keine Tageswerte.'),
        )
      else ...[
        // 1. Wie viel pro Person?
        ChartCard(
          title: 'Wie viel pro Person?',
          subtitle: 'Watt Dauerleistung pro Person, Bereich Wohnen',
          info: InfoTexts.wattPerPerson.fill(values),
          stand: stand,
          child: _PerPerson(
            summary: s,
            household: d.household,
            factors: d.factors,
            withPv: _withPv,
            onWithPv: (v) => setState(() => _withPv = v),
            short: short,
          ),
        ),
        // 2. Woher kommt die Energie?
        ChartCard(
          title: 'Woher kommt die Energie?',
          subtitle: 'Endenergie in kWh, Brennstoffe mit Heizwert umgerechnet',
          info: InfoTexts.energyMix.fill(values),
          stand: stand,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EnergyMixDonut(
                kwh: s.kwhByCarrier,
                estimated: {
                  for (final c in s.kwhByCarrier.keys)
                    if (c.isFuel) c,
                },
              ),
              if (s.unknownFuels.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${s.unknownFuels.map((t) => kFuelLabels[t] ?? t).join(', ')}: noch nicht '
                  'enthalten, dafür braucht es einen zweiten Eintrag.',
                  style: KwfText.small,
                ),
              ],
              if (s.hasPv && s.autarky != null) ...[
                const Divider(height: 28),
                AutarkyRing(autarky: s.autarky!, selfConsumption: s.selfConsumption),
              ],
            ],
          ),
        ),
        // 3. Monat fuer Monat (bei Woche und Monat: Tag fuer Tag)
        ChartCard(
          title: short ? 'Tag für Tag' : 'Monat für Monat',
          subtitle: 'kWh nach Energieträger, ${p.label}',
          info: InfoTexts.dailyBars,
          stand: stand,
          child: _EnergyBars(summary: s, short: short),
        ),
        // 4. Heizen
        if (s.heatElectricKwh > 0 || s.heatFuelKwh > 0)
          ChartCard(
            title: 'Heizen',
            subtitle: 'kWh Heizenergie, Strom der Heizung und Brennstoffe fürs Heizen',
            info: InfoTexts.heating,
            stand: stand,
            child: _Heating(summary: s, short: short),
          ),
        // 5. Wohnklima, 6. Belegung
        if (hasClimate) ...[
          ChartCard(
            title: 'Wie behaglich war es?',
            subtitle: 'Innen am Lieblingsort, ${s.occupiedDays > 0 ? 'an bewohnten Tagen' : 'alle Tage'}',
            info: InfoTexts.climate,
            stand: stand,
            child: _Climate(summary: s),
          ),
          ChartCard(
            title: 'Wann wart ihr zu Hause?',
            subtitle: 'Berechnet aus den CO2-Werten, nicht gemessen',
            info: InfoTexts.occupancy,
            stand: stand,
            child: _Occupancy(summary: s),
          ),
        ] else
          KwfCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wohnklima und Belegung', style: KwfText.sectionTitle),
                const SizedBox(height: 6),
                Text(
                    'Dein Monitor hat keinen Klimasensor. Ohne Temperatur und CO2 innen gibt es '
                    'kein Wohnklima und keine bewohnten Tage.',
                    style: KwfText.small),
                TextButton(
                  onPressed: () => context.push(Routes.measurementSchema),
                  child: const Text('Zum Mess-Schema'),
                ),
              ],
            ),
          ),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const ValueKey('to-method'),
          onPressed: () => context.push(Routes.method),
          icon: const Icon(Icons.functions, size: 18),
          label: const Text('So rechnen wir'),
        ),
      ),
    ]);
  }
}

class _DataNote extends StatelessWidget {
  const _DataNote({required this.summary});
  final PeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final parts = [
      '${s.daysWithData} von ${s.period.dayCount} Tagen mit Daten',
      if (s.gappyDays > 0) '${s.gappyDays} davon lückenhaft',
      standText(s.dataUntil),
    ];
    return Text(parts.join(' · '), style: KwfText.meta);
  }
}

class _PerPerson extends StatelessWidget {
  const _PerPerson({
    required this.summary,
    required this.household,
    required this.factors,
    required this.withPv,
    required this.onWithPv,
    required this.short,
  });
  final PeriodSummary summary;
  final List<HouseholdEntry> household;
  final EnergyFactors factors;
  final bool withPv;
  final ValueChanged<bool> onWithPv;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    if (s.personHours <= 0) return const PersonsMissingWarning();
    final missing = s.daysWithoutPersons;
    final mine = withPv ? s.wattsMinergieWithPv : s.wattsMinergie;
    final label = householdFor(household, s.period.until)?.labelWPerPerson;
    final bench2000 = [for (final b in factors.benchmarks) if (b.method == '2000watt') b];
    final rowsMinergie = <BenchmarkRow>[
      if (mine != null)
        BenchmarkRow('Euer Haus', withPv ? 'nach Minergie, mit Solarstrom' : 'nach Minergie, berechnet',
            mine,
            own: true),
      if (label != null) BenchmarkRow('KWF-Energielabel', 'berechnet, aus "Haushalt"', label),
    ];
    final rows2000 = <BenchmarkRow>[
      if (s.watts2000 != null)
        BenchmarkRow('Euer Haus', 'nach 2000 Watt, Primärenergie KBOB', s.watts2000!, own: true),
      for (final b in bench2000) BenchmarkRow(b.label, b.source ?? 'Vergleichswert', b.watts),
    ];
    final all = [...rowsMinergie, ...rows2000];
    final max = all.isEmpty ? 1.0 : all.map((r) => r.watts).reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (short)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: KwfHint('Kurze Zeiträume schwanken stark. Vergleichbar mit dem Label ist nur das Jahr.'),
          ),
        if (missing > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: KwfHint('Für $missing ${missing == 1 ? 'Tag' : 'Tage'} fehlen Personen im '
                'Haushalt. Diese Tage zählen hier nicht mit.'),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
              'Geteilt durch ${s.personsNow == 1 ? '1 Person' : '${s.personsNow} Personen'} aus '
              '"Haushalt"${s.daysPersonsAssumed > 0 ? '. Der erste Eintrag gilt auch für die '
                  '${s.daysPersonsAssumed} Tage davor' : ''}.',
              style: KwfText.meta),
        ),
        Text('Nach Minergie', style: KwfText.kicker),
        Text('Netz und Brennstoffe gewichtet, eigener Solarstrom gutgeschrieben',
            style: KwfText.meta),
        if (rowsMinergie.isEmpty)
          const ChartEmpty('Faktoren nach Minergie fehlen noch.')
        else
          PerPersonBenchmark(rows: rowsMinergie, scaleMax: max),
        SwitchListTile(
          key: const ValueKey('with-pv'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('mit Solarstrom', style: kwfText(13, weight: FontWeight.w500)),
          subtitle: const Text('zeigt den Wert ohne Gutschrift für den eigenen Solarstrom'),
          value: withPv,
          onChanged: onWithPv,
        ),
        const Divider(height: 20),
        Text('Nach 2000 Watt', style: KwfText.kicker),
        Text('Primärenergie, ohne eigenen Solarstrom', style: KwfText.meta),
        if (rows2000.isEmpty)
          const ChartEmpty('Primärenergiefaktoren fehlen noch.')
        else
          PerPersonBenchmark(rows: rows2000, scaleMax: max),
      ],
    );
  }
}

class _EnergyBars extends StatelessWidget {
  const _EnergyBars({required this.summary, required this.short});
  final PeriodSummary summary;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final spread = {
      for (final f in s.fuels.values)
        if (f.evenlySpread) ?Carrier.ofFuel(f.type),
    };
    final List<BarValue> bars;
    if (short) {
      final byDate = {for (final d in s.days) d.date: d};
      bars = [
        for (final date in s.period.days)
          if (byDate[date] case final d?)
            BarValue(date, {
              for (final e in d.kwh.entries)
                if (!spread.contains(e.key)) e.key: e.value,
            },
                estimated: d.estimated,
                note: d.gappy ? 'Daten lückenhaft' : null)
          else
            BarValue(date, const {}, note: 'keine Daten'),
      ];
    } else {
      final byMonth = {for (final m in s.months) m.month: m};
      final months = <DateTime>[
        for (var m = DateTime(s.period.start.year, s.period.start.month);
            !m.isAfter(s.period.until);
            m = DateTime(m.year, m.month + 1))
          m,
      ];
      bars = [
        for (final m in months)
          BarValue(m, byMonth[m]?.kwh ?? const {}, estimated: byMonth[m]?.estimated ?? const {}),
      ];
    }
    final carriers = {for (final b in bars) ...b.kwh.keys};
    final estimated = {for (final b in bars) ...b.estimated};
    final peak = bars.isEmpty ? null : bars.reduce((a, b) => a.total >= b.total ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (carriers.isNotEmpty) ChartLegend(carriers: carriers, estimated: estimated),
        const SizedBox(height: 10),
        StackedBars(
          bars: bars,
          labelEvery: short ? (bars.length > 10 ? 7 : 1) : 1,
          labelOf: (d) => short
              ? (bars.length > 10 ? DateFormat('d.M.').format(d) : kDayLabel.format(d).substring(0, 2))
              : kMonthLabel.format(d).substring(0, 3),
          tooltipDate: (d) => short ? kDayDate.format(d) : kMonthDate.format(d),
        ),
        if (peak != null && peak.total > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                'Am meisten: ${short ? kDayDate.format(peak.date) : kMonthDate.format(peak.date)} '
                'mit ${fmtKwh(peak.total)} kWh.',
                style: KwfText.small),
          ),
        for (final f in s.fuels.values)
          if (f.evenlySpread)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  '${kFuelLabels[f.type] ?? f.type}: ${f.kwh == null ? '' : '${fmtKwh(f.kwh!)} kWh, '}'
                  'geschätzt, im Zeitraum. Verteilung auf Tage nicht möglich (kein Klimasensor).',
                  style: KwfText.small),
            ),
      ],
    );
  }
}

class _Heating extends StatelessWidget {
  const _Heating({required this.summary, required this.short});
  final PeriodSummary summary;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final total = s.heatElectricKwh + s.heatFuelKwh;
    final solarShare = s.heatElectricKwh > 0 ? s.heatSolarKwh / s.heatElectricKwh : null;
    final rows = <(String, String)>[
      ('Heizenergie im Zeitraum', '${fmtKwh(total)} kWh'),
      if (s.heatElectricKwh > 0) ('davon Strom Heizung (I2)', '${fmtKwh(s.heatElectricKwh)} kWh'),
      if (solarShare != null) ('Solaranteil am Heizstrom', fmtPct(solarShare)),
      if (s.heatFuelKwh > 0) ('davon Brennstoffe Heizen (M2), geschätzt', '${fmtKwh(s.heatFuelKwh)} kWh'),
      if (s.fires > 0) ('Feuer erkannt', '${s.fires}'),
    ];
    final List<BarValue> bars = short
        ? [
            for (final d in s.days)
              BarValue(d.date, {
                if (d.heatSolar > 0) Carrier.solar: d.heatSolar,
                if (d.heatElectric - d.heatSolar > 0) Carrier.grid: d.heatElectric - d.heatSolar,
                if (d.heatFuel > 0) Carrier.wood: d.heatFuel,
              }, estimated: {if (d.heatFuel > 0) Carrier.wood}),
          ]
        : [
            for (final m in s.months)
              BarValue(m.month, {
                if (m.heatSolar > 0) Carrier.solar: m.heatSolar,
                if (m.heatElectric - m.heatSolar > 0) Carrier.grid: m.heatElectric - m.heatSolar,
                if (m.heatFuel > 0) Carrier.wood: m.heatFuel,
              }, estimated: {if (m.heatFuel > 0) Carrier.wood}),
          ];
    final carriers = {for (final b in bars) ...b.kwh.keys};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(child: Text(k, style: KwfText.small)),
              const SizedBox(width: 12),
              Text(v, style: kwfText(13, weight: FontWeight.w600)),
            ]),
          ),
        if (bars.length > 1 && carriers.isNotEmpty) ...[
          const SizedBox(height: 10),
          ChartLegend(carriers: carriers, estimated: {if (carriers.contains(Carrier.wood)) Carrier.wood}),
          const SizedBox(height: 8),
          StackedBars(
            bars: bars,
            height: 140,
            labelEvery: short && bars.length > 10 ? 7 : 1,
            labelOf: (d) => short
                ? (bars.length > 10 ? DateFormat('d.M.').format(d) : kDayLabel.format(d).substring(0, 2))
                : kMonthLabel.format(d).substring(0, 3),
            tooltipDate: (d) => short ? kDayDate.format(d) : kMonthDate.format(d),
          ),
        ],
      ],
    );
  }
}

class _Climate extends StatelessWidget {
  const _Climate({required this.summary});
  final PeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final tiles = <Widget>[
      if (s.tInMedian != null)
        ClimateTile(
          label: 'Temperatur',
          value: s.tInMedian!,
          unit: '°C',
          level: temperatureLevel(s.tInMedian!),
          word: temperatureWord(temperatureLevel(s.tInMedian!)),
          scale: kTempScale,
          range: s.tInP05 == null
              ? null
              : 'Bereich ${fmtNum(s.tInP05!)} bis ${fmtNum(s.tInP95!)} °C',
        ),
      if (s.rhMedian != null)
        ClimateTile(
          label: 'Feuchte',
          value: s.rhMedian!,
          unit: '%',
          level: humidityLevel(s.rhMedian!),
          word: humidityWord(humidityLevel(s.rhMedian!)),
          scale: kRhScale,
        ),
      if (s.co2Median != null)
        ClimateTile(
          label: 'CO2',
          value: s.co2Median!,
          unit: 'ppm',
          level: co2Level(s.co2Median!),
          word: co2Word(co2Level(s.co2Median!)),
          scale: kCo2Scale,
        ),
    ];
    final hw = s.hottestWeek;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 420 ? 3 : 2;
          final w = (c.maxWidth - 16 * (cols - 1)) / cols;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [for (final t in tiles) SizedBox(width: w, child: t)],
          );
        }),
        if (s.comfortHoursShare != null) ...[
          const SizedBox(height: 14),
          Text(
              '${fmtPct(s.comfortHoursShare!)} der Stunden zwischen '
              '${fmtNum(Comfort.tMin, digits: 0)} und ${fmtNum(Comfort.tMax, digits: 0)} °C.',
              style: KwfText.small),
        ],
        if (s.scatter.length >= 3) ...[
          const SizedBox(height: 12),
          ComfortZone(points: s.scatter),
        ],
        const Divider(height: 24),
        Row(children: [
          Expanded(child: Text('Stunden über 28 °C', style: KwfText.small)),
          Text(fmtNum(s.hoursOver28, digits: 0), style: kwfText(13, weight: FontWeight.w600)),
          InfoButton(text: InfoTexts.heat, stand: standText(s.dataUntil)),
        ]),
        if (hw != null)
          Row(children: [
            Expanded(
              child: Text(
                  'Heisseste Woche ab ${DateFormat('d.M.yyyy').format(hw.$1)}, tagsüber im Mittel',
                  style: KwfText.small),
            ),
            Text('${fmtNum(hw.$2)} °C', style: kwfText(13, weight: FontWeight.w600)),
          ]),
      ],
    );
  }
}

class _Occupancy extends StatelessWidget {
  const _Occupancy({required this.summary});
  final PeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final known = s.daysWithData - s.unknownOccupancyDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '${s.occupiedDays}', style: kwfText(28)),
            TextSpan(
                text: ' von $known Tagen bewohnt',
                style: kwfText(14, weight: FontWeight.w400)),
          ]),
        ),
        if (s.unknownOccupancyDays > 0)
          Text('${s.unknownOccupancyDays} Tage ohne genug CO2-Werte', style: KwfText.meta),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Text('CO2 über den Tag', style: KwfText.cardTitle)),
          InfoButton(text: InfoTexts.co2Heatmap, stand: standText(s.dataUntil)),
        ]),
        Text('Median pro Wochentag und Stunde, ppm', style: KwfText.meta),
        const SizedBox(height: 8),
        if (s.co2Days < 28)
          const ChartEmpty('Die Heatmap braucht mindestens vier Wochen mit CO2-Werten, sonst '
              'verrauscht das Muster. Wähle einen längeren Zeitraum.')
        else
          Co2Heatmap(cells: s.co2Heatmap),
      ],
    );
  }
}
