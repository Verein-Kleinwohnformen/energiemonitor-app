import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kwf_energiemonitor/user.dart';
import 'package:kwf_energiemonitor/energy.dart';

class EnergyList extends StatefulWidget {
  const EnergyList({super.key});

  @override
  State<EnergyList> createState() => _EnergyListState();
}

class _EnergyListState extends State<EnergyList> {
  EnergyCollection energyEntries = EnergyCollection.empty();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  _infoBox(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: Theme.of(context).colorScheme.primary,
        child: const ListTile(
          leading: Icon(Icons.info, color: Colors.white),
          title: Text(
            'Energieträger manuell hinzufügen',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            'Füge weitere Energieträger wie Holz, Gas, etc. hinzu, damit sie auf der Liste '
            'erscheinen. Am besten immer gleich, wenn du sie eingekauft oder '
            'dem System hinzugefügt hast.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    final form = GlobalKey<FormState>();
    String description = '';
    DateTime purchaseDate;
    DateTime usageDate;
    EnergyType type;
    double purchaseQuantity = 0;
    double leftoverQuantity = 0;

    bool isSending = false;

    Widget _doubleField(double ref, String labelText) {
      return TextFormField(
        decoration: InputDecoration(labelText: labelText),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autocorrect: false,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Bitte eine Zahl eingeben';
          }
          // Attempt to parse the input as a double
          final doubleValue = double.tryParse(value);
          if (doubleValue == null) {
            return 'Bitte eine gültige Zahl eingeben';
          }
          return null;
        },
        onSaved: (value) {
          // Save the parsed double value if it is valid
          ref = double.parse(value!);
        },
      );
    }

    Widget _descriptionField() {
      return TextFormField(
          decoration: const InputDecoration(labelText: 'Beschreibung'),
          keyboardType: TextInputType.name,
          autocorrect: false,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Bitte eine Beschreibung eingeben';
            }
            return null;
          },
          onSaved: (value) {
            description = value!;
          });
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Energieträger hinzufügen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Form(
                  key: form,
                  child: Column(children: [
                    _descriptionField(),
                    _doubleField(purchaseQuantity, "Gekaufte Menge"),
                    _doubleField(leftoverQuantity, "Übrige Menge"),
                  ]))
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                // Validate the form and save data
                if (form.currentState!.validate()) {
                  form.currentState!.save(); // Save the form data
                  // Add the new item to Firestore

                  energyEntries.addNew(
                      type: EnergyType.propane,
                      description: description,
                      purchaseQuantity: purchaseQuantity,
                      leftoverQuantity: leftoverQuantity);

                  Navigator.of(context).pop(); // Close the dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Eintrag hinzugefügt!")),
                  );
                } else {
                  print("Form not validated");
                }
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        );
      },
    );
  }

  manuallyAddedEnergy() {
    return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        floatingActionButton: AppUser().activeMonitor != null
            ? FloatingActionButton(
                onPressed: () => _showAddItemDialog(context),
                tooltip: "Energieträger hinzufügen",
                child: const Icon(Icons.add))
            : null,
        body: Padding(
            padding: const EdgeInsets.all(8.0),
            child: AppUser().activeMonitor == null
                ? const Text("Kein Energiemonitor aktiv!")
                : StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('manual_input').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      "Dein Monitor: ${AppUser().activeMonitor!.tinyhouseName}"),
                                  Center(child: _infoBox(context)),
                                ]));
                      }

                      energyEntries = EnergyCollection.fromSnapshot(snapshot);

                      return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    "Dein Monitor: ${AppUser().activeMonitor!.tinyhouseName}"),
                                Expanded(
                                    child: ListView.builder(
                                  itemCount: energyEntries.length +
                                      1, // +1 for the static info card
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      // First item: Info card
                                      return _infoBox(context);
                                    } else {
                                      // Other items: Loaded dynamically from Firebase
                                      final energy =
                                          energyEntries.energyCol[index - 1];
                                      return Card(
                                        child: ListTile(
                                          title: Text(energy.description ??
                                              'Keine Beschreibung'),
                                          subtitle: Text(
                                              energy.type.name ?? 'Kein Typ'),
                                        ),
                                      );
                                    }
                                  },
                                ))
                              ]));
                    },
                  )));
  }
}
