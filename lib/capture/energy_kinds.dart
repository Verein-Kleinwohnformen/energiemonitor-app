// Energietraeger und Messpunkte des Formulars. Fachlich unveraendert
// gegenueber dem alten Formular (lib/legacy/energy_form_legacy.dart):
// gleiche Traeger, gleiche Einheiten, gleiche Kuerzel.
import 'package:flutter/material.dart';

import '../energy.dart';
import '../theme/kwf_tokens.dart';

/// Ein waehlbarer Energietraeger. Holz ist ein Traeger mit zwei Einheiten,
/// gespeichert als woodKg oder woodSter.
enum EnergyKind {
  wood('Holz', ['Kg', 'Ster'], Icons.forest_outlined, KwfColors.dataHolz),
  pellets('Holzpellets', ['Kg'], Icons.grain, KwfColors.dataHolz),
  propane('Propangas', ['Kg'], Icons.propane_tank_outlined, KwfColors.dataGas),
  oil('Heizöl', ['Liter'], Icons.oil_barrel_outlined, KwfColors.textSekundaer),
  diesel('Diesel', ['Liter'], Icons.local_gas_station_outlined, KwfColors.textSekundaer),
  gasoline('Benzin', ['Liter'], Icons.local_gas_station_outlined, KwfColors.textSekundaer);

  const EnergyKind(this.label, this.units, this.icon, this.color);

  /// Beschriftung wie im alten Formular.
  final String label;

  /// Einheiten wie im alten Formular ('Kg', 'Ster', 'Liter').
  final List<String> units;
  final IconData icon;

  /// Farbe der Vorrat-Karte. Heizoel, Diesel und Benzin haben im Design
  /// System keine eigene Traegerfarbe.
  /// TODO(prüfen): Farbe fuer Heizoel, Diesel, Benzin mit dem Design System klaeren.
  final Color color;

  bool get hasUnitChoice => units.length > 1;

  /// Gleiche Regel wie `_manageUnits` im alten Formular: Holz in Ster wird
  /// woodSter, sonst woodKg.
  EnergyType typeFor(String? unit) => switch (this) {
        EnergyKind.wood => unit == 'Ster' ? EnergyType.woodSter : EnergyType.woodKg,
        EnergyKind.pellets => EnergyType.pellets,
        EnergyKind.propane => EnergyType.propane,
        EnergyKind.oil => EnergyType.oil,
        EnergyKind.diesel => EnergyType.diesel,
        EnergyKind.gasoline => EnergyType.gasoline,
      };

  static EnergyKind of(EnergyType t) => switch (t) {
        EnergyType.woodKg || EnergyType.woodSter => EnergyKind.wood,
        EnergyType.pellets => EnergyKind.pellets,
        EnergyType.propane => EnergyKind.propane,
        EnergyType.oil => EnergyKind.oil,
        EnergyType.diesel => EnergyKind.diesel,
        EnergyType.gasoline => EnergyKind.gasoline,
      };

  /// Einheit eines gespeicherten Typs, wie sie das Formular anbietet.
  static String unitOf(EnergyType t) => switch (t) {
        EnergyType.woodSter => 'Ster',
        EnergyType.oil || EnergyType.diesel || EnergyType.gasoline => 'Liter',
        _ => 'Kg',
      };
}

/// Anzeige einer Einheit im Text ("kg", "Ster", "Liter").
String unitText(String unit) => unit == 'Kg' ? 'kg' : unit;

/// Messpunkte des Formulars. Gespeichert wird das Kuerzel.
/// Bedeutung von M0 bis M2 nicht aendern (offene Frage mit der HSLU).
class MeteringChoice {
  const MeteringChoice(this.code, this.label);
  final String code;
  final String label;
}

const kMeteringChoices = [
  MeteringChoice('M1', 'Warmwasser'),
  MeteringChoice('M2', 'Heizen'),
  MeteringChoice('M0', 'Gemischt'),
];

/// Bezeichnung wie in den Listen des alten Formulars ("M1 Warmwasser").
String meteringText(String code) => switch (code) {
      'M0' => 'M0 Gemischt',
      'M1' => 'M1 Warmwasser',
      'M2' => 'M2 Heizwärme',
      _ => code,
    };
