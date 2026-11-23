import 'package:flutter/material.dart';

import '../app/services.dart';
import '../charts/chart_basics.dart';
import '../daily/factors.dart';
import '../daily/summary.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_widgets.dart';
import 'sub_page.dart';

/// "So rechnen wir": Systemgrenze und Herkunft der Faktoren. Die Faktoren
/// kommen aus /config/factors und stehen nicht im Code.
class MethodPage extends StatelessWidget {
  const MethodPage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    return FutureBuilder<EnergyFactors>(
      future: services.factors.load(),
      builder: (context, snap) => MethodView(factors: snap.data),
    );
  }
}

class MethodView extends StatelessWidget {
  const MethodView({super.key, this.factors});

  /// null: wird noch geladen.
  final EnergyFactors? factors;

  @override
  Widget build(BuildContext context) {
    Widget card(String title, List<Widget> body) => KwfCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: KwfText.sectionTitle),
              const SizedBox(height: 6),
              ...body,
            ],
          ),
        );
    Widget text(String s) => Text(s, style: KwfText.body);
    final f = factors;
    return SubPage(title: 'So rechnen wir', children: [
      card('Pro Person, nicht pro Fläche', [
        text('Die Kennzahl des Vereins ist Watt Dauerleistung pro Person: die Energie im '
            'Zeitraum geteilt durch die Stunden und die Personen im Haushalt.'),
      ]),
      card('Zwei Systemgrenzen', [
        text('Nach Minergie zählen Strom und Brennstoffe mit ihrem Gewichtungsfaktor. Eigener '
            'Solarstrom, den ihr selbst nutzt, wird ganz gutgeschrieben, eingespeister zum Teil. '
            'Diesen Wert vergleichen wir mit dem KWF-Energielabel.'),
        const SizedBox(height: 8),
        text('Nach der 2000-Watt-Methodik zählen Netzstrom und Brennstoffe mit ihrem '
            'Primärenergiefaktor, eigener Solarstrom zählt nicht. Diesen Wert vergleichen wir '
            'mit dem 2000-Watt-Ziel und der Schweiz heute.'),
        const SizedBox(height: 8),
        text('Diesel und Benzin gehören nicht zum Wohnen und zählen nicht mit.'),
      ]),
      card('Gemessen, berechnet, geschätzt', [
        text('Strom messen Victron und Shelly direkt. Holz, Pellets und Gas kennen wir nur aus '
            'deinen Einträgen. Wann du sie verbraucht hast, schätzen wir: Pellets und Holz '
            'über den Temperaturverlauf, Gas über die bewohnten Tage. Jede Zahl in der App '
            'sagt im Info-Symbol, wie sie entstanden ist.'),
      ]),
      card('Faktoren', [
        if (f == null)
          const Center(child: CircularProgressIndicator())
        else if (f.heatingValues.isEmpty && f.weighting.isEmpty && f.primaryEnergy.isEmpty)
          text('Die Faktoren sind noch nicht hinterlegt.')
        else ...[
          _FactorTable(
            title: 'Heizwert',
            rows: {
              for (final e in f.heatingValues.entries)
                if (kFuelLabels[e.key] != null)
                  kFuelLabels[e.key]!: '${fmtNum(e.value, digits: 3)} ${f.heatingUnits[e.key] ?? ''}',
            },
            source: f.heatingSource,
          ),
          _FactorTable(
            title: 'Gewichtung nach Minergie',
            rows: {
              if (f.weighting['electricity'] != null)
                'Strom': fmtNum(f.weighting['electricity']!, digits: 2),
              for (final e in f.weighting.entries)
                if (kFuelLabels[e.key] != null) kFuelLabels[e.key]!: fmtNum(e.value, digits: 2),
              if (f.pvSelfConsumptionCredit != null)
                'Solarstrom selbst genutzt, angerechnet': fmtPct(f.pvSelfConsumptionCredit!),
              if (f.pvFeedInCredit != null)
                'Solarstrom eingespeist, angerechnet': fmtPct(f.pvFeedInCredit!),
            },
            source: f.weightingSource,
          ),
          _FactorTable(
            title: 'Primärenergie nach KBOB (gesamt)',
            rows: {
              if (f.primaryEnergy['electricity'] != null)
                'Strom (CH-Verbrauchermix)': fmtNum(f.primaryEnergy['electricity']!, digits: 2),
              for (final e in f.primaryEnergy.entries)
                if (kFuelLabels[e.key] != null) kFuelLabels[e.key]!: fmtNum(e.value, digits: 2),
            },
            source: f.primarySource,
          ),
          if (f.benchmarks.isNotEmpty)
            _FactorTable(
              title: 'Vergleichswerte',
              rows: {
                for (final b in f.benchmarks)
                  b.label: "${fmtNum(b.watts, digits: 0)} W${b.source == null ? '' : ', ${b.source}'}",
              },
            ),
          if (f.updatedAt != null) Text('Stand ${f.updatedAt}', style: KwfText.meta),
        ],
      ]),
    ]);
  }
}

class _FactorTable extends StatelessWidget {
  const _FactorTable({required this.title, required this.rows, this.source});
  final String title;
  final Map<String, String> rows;
  final String? source;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: KwfText.cardTitle),
          const SizedBox(height: 4),
          for (final e in rows.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(child: Text(e.key, style: KwfText.small)),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(e.value,
                      textAlign: TextAlign.right,
                      style: kwfText(13, weight: FontWeight.w600)),
                ),
              ]),
            ),
          if (source != null) Text('Quelle: $source', style: KwfText.meta),
        ],
      ),
    );
  }
}
