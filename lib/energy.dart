import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum EnergyType { woodSter, woodKg, propane, pellets, oil, diesel, gasoline }

String energyTypeToString(EnergyType energyType) {
  return energyType.toString().split('.').last;
}

EnergyType energyTypeFromString(String type) {
  switch (type) {
    case 'woodSter':
      return EnergyType.woodSter;
    case 'woodKg':
      return EnergyType.woodKg;
    case 'propane':
      return EnergyType.propane;
    case 'pellets':
      return EnergyType.pellets;
    case 'oil':
      return EnergyType.oil;
    case 'diesel':
      return EnergyType.diesel;
    case 'gasoline':
      return EnergyType.gasoline;
    default:
      throw Exception("Unknown energy type: ${type}");
  }
}

class EnergyCollection {
  List<Energy> energyCol = [];

  EnergyCollection.fromSnapshot(snapshot) {
    energyCol = snapshot.data!.docs
        .map((doc) =>
            Energy.fromFirebase(doc.id, doc.data() as Map<String, dynamic>))
        .toList()
        .cast<Energy>();
    energyCol.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
  }
  // Empty constructor for initialization
  EnergyCollection.empty();

  int get length => energyCol.length;

  addNew(
      {required EnergyType type,
      required String description,
      required double purchaseQuantity,
      required double leftoverQuantity}) {
    Energy newEntry = Energy(
        firebaseId: '',
        typeCounter: 0,
        description: description,
        purchaseDate: DateTime.now(),
        usageDate: DateTime.now(),
        type: type,
        purchaseQuantity: purchaseQuantity,
        leftoverQuantity: leftoverQuantity);

    // Store on firebase
    newEntry.addToFirebase();

    // Add to list
    energyCol.add(newEntry);
    // Sort the list again
    energyCol.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
  }
}

class Energy {
  String firebaseId;
  int typeCounter;
  String description;
  DateTime purchaseDate;
  DateTime usageDate;
  EnergyType type;
  double purchaseQuantity;
  double leftoverQuantity;

  // Default constructor with optional parameters and initialization
  Energy({
    required this.firebaseId,
    required this.typeCounter,
    required this.description,
    required this.purchaseDate,
    required this.usageDate,
    required this.type,
    required this.purchaseQuantity,
    required this.leftoverQuantity,
  });

  String get imageString {
    switch (type) {
      case EnergyType.diesel:
        return 'assets/diesel.png';
      case EnergyType.woodSter:
        return 'assets/wood.png';
      case EnergyType.woodKg:
        return 'assets/wood.png';
      case EnergyType.gasoline:
        return 'assets/benzin.png';
      case EnergyType.oil:
        return 'assets/oil.png';
      case EnergyType.pellets:
        return 'assets/pellets.png';
      case EnergyType.propane:
        return 'assets/propane.png';
    }
  }

  String get displayUnit {
    switch (type) {
      case EnergyType.diesel:
        return 'Liter';
      case EnergyType.woodSter:
        return 'Ster';
      case EnergyType.woodKg:
        return 'kg';
      case EnergyType.gasoline:
        return 'Liter';
      case EnergyType.oil:
        return 'Liter';
      case EnergyType.pellets:
        return 'kg';
      case EnergyType.propane:
        return 'kg';
    }
  }

  String get formattedDescription {
    switch (type) {
      case EnergyType.diesel:
        return 'Diesel';
      case EnergyType.woodSter:
        return 'Holz';
      case EnergyType.woodKg:
        return 'Holz';
      case EnergyType.gasoline:
        return 'Benzin';
      case EnergyType.oil:
        return 'Heizöl';
      case EnergyType.pellets:
        return 'Pellets';
      case EnergyType.propane:
        return 'Propangas';
    }
  }

// Factory constructor to create an Energy instance from Firebase data
  factory Energy.fromFirebase(String id, Map<String, dynamic> data) {
    return Energy(
      firebaseId: id,
      typeCounter: data['type_counter'] ?? 0,
      description: data['description'] ?? '',
      purchaseDate: (data['purchase_date'] as Timestamp).toDate(),
      usageDate: (data['usage_date'] as Timestamp).toDate(),
      type: energyTypeFromString(data['type']),
      purchaseQuantity: (data['added_quantity'] ?? 0).toDouble(),
      leftoverQuantity: (data['leftover_quantity'] ?? 0).toDouble(),
    );
  }

  delete() async {
    await FirebaseFirestore.instance
        .collection('manual_input')
        .doc(firebaseId)
        .delete();
  }

  addToFirebase() async {
    await FirebaseFirestore.instance.collection('manual_input').add({
      'type_counter': typeCounter,
      'description': description,
      'purchase_date': purchaseDate,
      'usage_date': usageDate,
      'type': type.name,
      'purchase_quantity': purchaseQuantity,
      'leftover_quantity': leftoverQuantity
    });
  }

  // toString method for a readable format
  @override
  String toString() {
    final dateFormatter = DateFormat('yyyy-MM-dd');
    return 'Energy(counter: $typeCounter, description: "$description", purchaseDate: ${dateFormatter.format(purchaseDate)}, usageDate: ${dateFormatter.format(usageDate)}, type: $type, purchaseQuantity: $purchaseQuantity, leftoverQuantity: $leftoverQuantity)';
  }
}
