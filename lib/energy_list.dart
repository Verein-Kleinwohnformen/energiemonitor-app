import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kwf_energiemonitor/user.dart';
import 'package:kwf_energiemonitor/energy.dart';
import 'package:kwf_energiemonitor/energy_form.dart';
import 'package:kwf_energiemonitor/energy_card.dart';

class EnergyList extends StatefulWidget {
  const EnergyList({super.key});

  @override
  State<EnergyList> createState() => _EnergyListState();
}

class _EnergyListState extends State<EnergyList> {
  EnergyCollection energyEntries = EnergyCollection.empty();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _refreshKey = 0;

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

  _deinMonitor() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(
            "Aktiver Energiemonitor: ${AppUser().activeMonitor!.tinyhouseName}"),
        if (AppUser().hasMultipleMonitors)
          IconButton(
              onPressed: () {
                setState(() {
                  AppUser().changeActiveMonitorRead();
                });
              },
              icon: const Icon(Icons.change_circle))
      ]),
      if (!AppUser().canEditActiveMonitor)
        Text("Du kannst bei diesem Monitor keine Daten hinzufügen",
            style: Theme.of(context)
                .textTheme
                .labelSmall!
                .copyWith(fontWeight: FontWeight.bold))
    ]);
  }

  Future<EnergyCollection> _loadManualEntries(String deviceId) async {
    final currentYear = DateTime.now().year;
    final years = [currentYear, currentYear - 1]; // Current and last year

    final allEntries = <Energy>[];

    // Query each year
    for (final year in years) {
      try {
        final snapshot = await _firestore
            .collection('devices')
            .doc(deviceId)
            .collection('manual')
            .doc(year.toString())
            .collection('data')
            .get();

        for (final doc in snapshot.docs) {
          try {
            final energy = Energy.fromFirebase(doc.id, doc.data());
            allEntries.add(energy);
          } catch (e) {
            print('Error parsing entry ${doc.id}: $e');
          }
        }
      } catch (e) {
        // Year collection might not exist yet, continue
        print('Error loading year $year: $e');
      }
    }

    if (allEntries.isEmpty) {
      return EnergyCollection.empty();
    }

    // Sort by purchase date (newest first)
    allEntries.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));

    final collection = EnergyCollection.empty();
    collection.energyCol = allEntries;
    return collection;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: SizedBox(
            width: 600,
            child: Scaffold(
                floatingActionButton: AppUser().canEditActiveMonitor
                    ? FloatingActionButton(
                        onPressed: () async {
                          final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) => const EnergyForm()));
                          if (result == true) {
                            setState(() {
                              _refreshKey++;
                            });
                          }
                        },
                        tooltip: "Energieträger hinzufügen",
                        child: const Icon(Icons.add))
                    : null,
                body: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: AppUser().activeMonitor == null
                        ? const Text("Kein Energiemonitor aktiv!")
                        : FutureBuilder<EnergyCollection>(
                            key: ValueKey(
                                '${AppUser().activeMonitor?.id}-$_refreshKey'),
                            future:
                                _loadManualEntries(AppUser().activeMonitor!.id),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              if (snapshot.hasError) {
                                return Center(
                                    child: Text('Fehler: ${snapshot.error}'));
                              }

                              energyEntries =
                                  snapshot.data ?? EnergyCollection.empty();

                              if (energyEntries.length == 0) {
                                return Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _deinMonitor(),
                                          Center(child: _infoBox(context))
                                        ]));
                              }

                              return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _deinMonitor(),
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
                                              final energy = energyEntries
                                                  .energyCol[index - 1];
                                              return EnergyCard(
                                                energy,
                                                onDeleted: () {
                                                  setState(() {
                                                    _refreshKey++;
                                                  });
                                                },
                                              );
                                            }
                                          },
                                        ))
                                      ]));
                            },
                          )))));
  }
}
