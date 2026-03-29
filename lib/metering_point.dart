import 'package:flutter/material.dart';

/// Model für einen Messpunkt
class MeteringPoint {
  final String deviceId;
  final String meteringPointId;
  final int firstSeen;
  final int lastSeen;
  final List<String> sensorTypes;
  final List<String> valueFields;

  MeteringPoint({
    required this.deviceId,
    required this.meteringPointId,
    required this.firstSeen,
    required this.lastSeen,
    required this.sensorTypes,
    required this.valueFields,
  });

  factory MeteringPoint.fromFirestore(
      String deviceId, String meteringPointId, Map<String, dynamic> data) {
    return MeteringPoint(
      deviceId: deviceId,
      meteringPointId: meteringPointId,
      firstSeen: data['first_seen'] ?? 0,
      lastSeen: data['last_seen'] ?? 0,
      sensorTypes: (data['sensor_types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      valueFields: (data['value_fields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  /// Gibt die Kategorie basierend auf dem Messpunkt-Prefix zurück
  MeteringPointCategory get category {
    if (meteringPointId.startsWith('E')) {
      return MeteringPointCategory.external;
    } else if (meteringPointId.startsWith('I')) {
      return MeteringPointCategory.internal;
    } else if (meteringPointId.startsWith('M')) {
      return MeteringPointCategory.material;
    } else if (meteringPointId.startsWith('D')) {
      return MeteringPointCategory.water;
    } else if (meteringPointId.startsWith('K')) {
      return MeteringPointCategory.comfort;
    } else if (meteringPointId.startsWith('A')) {
      return MeteringPointCategory.other;
    } else if (meteringPointId.startsWith('NA')) {
      return MeteringPointCategory.undefined;
    }
    return MeteringPointCategory.undefined;
  }

  /// Prüft ob der Messpunkt online ist (< 24h seit letzter Messung)
  /// Manuelle Punkte (M-Prefix) gelten nicht als online/offline
  bool get isOnline {
    if (meteringPointId.startsWith('M')) {
      return false; // Manuelle Punkte haben keinen Online-Status
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - lastSeen;
    const oneDayInMs = 24 * 60 * 60 * 1000;
    return diff < oneDayInMs;
  }

  /// Prüft ob der Messpunkt offline ist (24h-30 Tage seit letzter Messung)
  /// Manuelle Punkte (M-Prefix) gelten nicht als online/offline
  bool get isOffline {
    if (meteringPointId.startsWith('M')) {
      return false; // Manuelle Punkte haben keinen Online-Status
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - lastSeen;
    const oneDayInMs = 24 * 60 * 60 * 1000;
    const thirtyDaysInMs = 30 * 24 * 60 * 60 * 1000;
    return diff >= oneDayInMs && diff < thirtyDaysInMs;
  }

  /// Prüft ob der Messpunkt aktiv war (< 30 Tage seit letzter Messung)
  bool get isActive {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - lastSeen;
    const thirtyDaysInMs = 30 * 24 * 60 * 60 * 1000;
    return diff < thirtyDaysInMs;
  }

  /// Zeigt ob für diesen Messpunkt ein Online/Offline-Status relevant ist
  bool get hasOnlineStatus {
    return !meteringPointId.startsWith('M');
  }
}

/// Kategorien für Messpunkte basierend auf Prefix
enum MeteringPointCategory {
  external, // E1-E3: Externe Messpunkte (grün)
  internal, // I1-I3: Interne Messpunkte (gelb)
  water, // D1: Wasser (blau)
  comfort, // K0-K4: Wohnkomfort (lila)
  material, // M1-M2: Gas/Brennholz (rot/rosa)
  other, // A1: Abzug (grau)
  undefined, // NA: Nicht definiert (weiß)
}

/// Statische Definitionen für Messpunkte
class MeteringPointDefinitions {
  static final Map<String, MeteringPointInfo> definitions = {
    // Externe Messpunkte
    'E1': MeteringPointInfo(
      id: 'E1',
      name: 'Netzbezug el. Energie',
      unit: 'kWh',
      category: MeteringPointCategory.external,
    ),
    'E2': MeteringPointInfo(
      id: 'E2',
      name: 'Rückspeisung el. Energie',
      unit: 'kWh',
      category: MeteringPointCategory.external,
    ),
    'E3': MeteringPointInfo(
      id: 'E3',
      name: 'Eigenproduktion el. Energie',
      unit: 'kWh',
      category: MeteringPointCategory.external,
    ),

    // Interne Messpunkte
    'I1': MeteringPointInfo(
      id: 'I1',
      name: 'Warmwassererzeugung',
      unit: 'kWh / kg Gas',
      category: MeteringPointCategory.internal,
    ),
    'I2': MeteringPointInfo(
      id: 'I2',
      name: 'Energiebedarf Heizung',
      unit: 'kWh / kg / Ster',
      category: MeteringPointCategory.internal,
    ),
    'I3': MeteringPointInfo(
      id: 'I3',
      name: 'Kleinverbraucher',
      unit: 'kWh',
      category: MeteringPointCategory.internal,
    ),

    // Wasser
    'D1': MeteringPointInfo(
      id: 'D1',
      name: 'Gesamtwasserverbrauch',
      unit: 'm3',
      category: MeteringPointCategory.water,
    ),

    // Wohnkomfort
    'K1': MeteringPointInfo(
      id: 'K1',
      name: 'Innentemperatur, Lieblingsort',
      unit: '°C',
      category: MeteringPointCategory.comfort,
    ),
    'K2': MeteringPointInfo(
      id: 'K2',
      name: 'Aussentemperatur N, Schatten',
      unit: '°C',
      category: MeteringPointCategory.comfort,
    ),
    'K3': MeteringPointInfo(
      id: 'K3',
      name: 'Luftfeuchtigkeit, Lieblingsort',
      unit: '% RH',
      category: MeteringPointCategory.comfort,
    ),
    'K4': MeteringPointInfo(
      id: 'K4',
      name: 'CO2-Gehalt, Lieblingsort',
      unit: 'ppm',
      category: MeteringPointCategory.comfort,
    ),
    'K0': MeteringPointInfo(
      id: 'K0',
      name: 'Wohnkomfort kombiniert',
      unit: '',
      category: MeteringPointCategory.comfort,
    ),

    // Material
    'M0': MeteringPointInfo(
      id: 'M0',
      name: 'Gemischt',
      unit: '',
      category: MeteringPointCategory.material,
    ),
    'M1': MeteringPointInfo(
      id: 'M1',
      name: 'Gas in Flaschen',
      unit: 'kg',
      category: MeteringPointCategory.material,
    ),
    'M2': MeteringPointInfo(
      id: 'M2',
      name: 'Brennholz oder Pellets',
      unit: 'kg, Ster',
      category: MeteringPointCategory.material,
    ),

    // Andere
    'A1': MeteringPointInfo(
      id: 'A1',
      name: 'Abzug Verbrauch Energiemonitor',
      unit: 'kWh',
      category: MeteringPointCategory.other,
    ),

    // Nicht definiert
    'NA': MeteringPointInfo(
      id: 'NA',
      name: 'Nicht definiert',
      unit: '',
      category: MeteringPointCategory.undefined,
    ),
  };

  static MeteringPointInfo getInfo(String meteringPointId) {
    return definitions[meteringPointId] ??
        MeteringPointInfo(
          id: meteringPointId,
          name: 'Unbekannter Messpunkt',
          unit: '',
          category: MeteringPointCategory.undefined,
        );
  }

  static Color getCategoryColor(MeteringPointCategory category) {
    switch (category) {
      case MeteringPointCategory.external:
        return const Color(0xFFC8E6C9); // Hellgrün
      case MeteringPointCategory.internal:
        return const Color(0xFFFFF9C4); // Hellgelb
      case MeteringPointCategory.water:
        return const Color(0xFFB3E5FC); // Hellblau
      case MeteringPointCategory.comfort:
        return const Color(0xFFE1BEE7); // Hellviolett
      case MeteringPointCategory.material:
        return const Color(0xFFFFCCBC); // Hellorange/Rosa
      case MeteringPointCategory.other:
        return const Color(0xFFEEEEEE); // Grau
      case MeteringPointCategory.undefined:
        return const Color(0xFFFFFFFF); // Weiß
    }
  }

  static String getCategoryName(MeteringPointCategory category) {
    switch (category) {
      case MeteringPointCategory.external:
        return 'Externe Messpunkte';
      case MeteringPointCategory.internal:
        return 'Interne Messpunkte';
      case MeteringPointCategory.water:
        return 'Wasser';
      case MeteringPointCategory.comfort:
        return 'Wohnkomfort';
      case MeteringPointCategory.material:
        return 'Material';
      case MeteringPointCategory.other:
        return 'Andere';
      case MeteringPointCategory.undefined:
        return 'Nicht definiert';
    }
  }
}

/// Info über einen Messpunkt
class MeteringPointInfo {
  final String id;
  final String name;
  final String unit;
  final MeteringPointCategory category;

  MeteringPointInfo({
    required this.id,
    required this.name,
    required this.unit,
    required this.category,
  });
}
