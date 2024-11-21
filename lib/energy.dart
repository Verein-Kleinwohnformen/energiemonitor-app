import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum EnergyType { woodSter, woodKg, propane, pellets, oil, diesel, gasoline }

String energyTypeToString(EnergyType energyType) {
  return energyType.toString().split('.').last;
}

EnergyType energyTypeFromString(String type) {
  switch (type.toLowerCase()) {
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
      throw Exception("Unknown energy type");
  }
}

class EnergyCollection {
  List<Energy> energyCol = [];

  EnergyCollection.fromSnapshot(snapshot) {
    energyCol = snapshot.data!.docs
        .map((doc) => Energy.fromFirebase(doc.data() as Map<String, dynamic>))
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
  int typeCounter;
  String description;
  DateTime purchaseDate;
  DateTime usageDate;
  EnergyType type;
  double purchaseQuantity;
  double leftoverQuantity;

  // Default constructor with optional parameters and initialization
  Energy({
    required this.typeCounter,
    required this.description,
    required this.purchaseDate,
    required this.usageDate,
    required this.type,
    required this.purchaseQuantity,
    required this.leftoverQuantity,
  });

// Factory constructor to create an Energy instance from Firebase data
  factory Energy.fromFirebase(Map<String, dynamic> data) {
    return Energy(
      typeCounter: data['type_counter'] ?? 0,
      description: data['description'] ?? '',
      purchaseDate: (data['purchase_date'] as Timestamp).toDate(),
      usageDate: (data['usage_date'] as Timestamp).toDate(),
      type: energyTypeFromString(data['type']),
      purchaseQuantity: (data['purchase_quantity'] ?? 0).toDouble(),
      leftoverQuantity: (data['leftover_quantity'] ?? 0).toDouble(),
    );
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
