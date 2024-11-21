import 'package:flutter/material.dart';
import 'package:kwf_energiemonitor/energy.dart';

class EnergyForm extends StatefulWidget {
  const EnergyForm({super.key});

  @override
  State<EnergyForm> createState() => _EnergyFormState();
}

class _EnergyFormState extends State<EnergyForm> {
  final _formKey = GlobalKey<FormState>();

  // Field values
  String description = '';
  DateTime? purchaseDate;
  DateTime? usageDate;
  EnergyType? selectedType;
  String? selectedUnit;
  double purchaseQuantity = 0.0;
  double leftoverQuantity = 0.0;

  Map<String, dynamic>? get selectedCategory {
    if (selectedType == null) {
      return null;
    } else {
      // Find the first category that matches the selected type
      return categories
          .firstWhere((category) => category['type'] == selectedType);
    }
  }

  List<String> get unitList {
    if (selectedCategory == null) {
      return ['--'];
    } else {
      return selectedCategory!['units'];
    }
  }

  // Categories for selection
  final List<Map<String, dynamic>> categories = [
    {
      'icon': 'assets/benzin.png',
      'label': 'Benzin',
      'type': EnergyType.gasoline,
      'units': ['Liter']
    },
    {
      'icon': 'assets/diesel.png',
      'label': 'Diesel',
      'type': EnergyType.diesel,
      'units': ['Liter']
    },
    {
      'icon': 'assets/oil.png',
      'label': 'Heizöl',
      'type': EnergyType.oil,
      'units': ['Liter']
    },
    {
      'icon': 'assets/pellets.png',
      'label': 'Holzpellets',
      'type': EnergyType.pellets,
      'units': ['Kg']
    },
    {
      'icon': 'assets/propane.png',
      'label': 'Propangas',
      'type': EnergyType.propane,
      'units': ['Kg']
    },
    {
      'icon': 'assets/wood.png',
      'label': 'Holz',
      'type': EnergyType.woodKg,
      'units': ['Kg', 'Ster']
    },
  ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Energieträger hinzufügen'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _typeSelector(primaryColor),
                const SizedBox(height: 16),
                Text("Deine eigene Beschreibung",
                    style: Theme.of(context).textTheme.labelSmall),
                _descriptionField(),
                const SizedBox(height: 16),
                Text("Wieviel hast du dem System hinzugefügt?",
                    style: Theme.of(context).textTheme.labelSmall),
                _quantityRow("Hinzugefügte Menge", purchaseQuantity),
                const SizedBox(height: 16),
                Text("Wieviel hast du noch übrig?",
                    style: Theme.of(context).textTheme.labelSmall),
                _quantityRow("Übrige Menge", leftoverQuantity),
                const SizedBox(height: 16),
                Text("Wann hast du diese Menge hinzugefügt?",
                    style: Theme.of(context).textTheme.labelSmall),
                _dateField("Kaufdatum eingeben", purchaseDate,
                    (date) => purchaseDate = date),
                const SizedBox(height: 16),
                Text("Bis wann schätzt du, ist diese Menge aufgebraucht?",
                    style: Theme.of(context).textTheme.labelSmall),
                _dateField("Verbrauchsdatum eingeben", usageDate,
                    (date) => usageDate = date),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Abbrechen'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          //Todo: Add energy to db
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Eintrag hinzugefügt!")),
                          );
                        }
                      },
                      child: const Text('Hinzufügen'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeSelector(Color primaryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: categories.map((category) {
        final bool isSelected = category['type'] == selectedType;
        return GestureDetector(
          onTap: () {
            setState(() {
              selectedType = category['type'];
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? primaryColor : Colors.grey,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected ? primaryColor : Colors.white,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.asset(
                      category['icon'],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category['label'],
                  style: TextStyle(
                      color: isSelected ? primaryColor : Colors.grey,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _quantityRow(String text, double field) {
    return Row(children: [
      Expanded(
          child: _doubleField(
        (value) => field = value,
        text,
      )),
      Expanded(
          child: _unitField(unitList, selectedUnit, (u) {
        setState(() {
          selectedUnit = u;
        });
      }))
    ]);
  }

  Widget _unitField(List<String> units, String? selectedUnit,
      ValueChanged<String?> onChanged) {
    // Remove duplicates from the units list
    units = units.toSet().toList();

    // Ensure selectedUnit is valid. If not, reset it to the first item.
    if (selectedUnit != null && !units.contains(selectedUnit)) {
      selectedUnit = units.isNotEmpty ? units[0] : null;
    } else if (selectedUnit == null && units.isNotEmpty) {
      // If selectedUnit is null, default to the first item in the new list
      selectedUnit = units[0];
    }

    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
      ),
      value: selectedUnit,
      items: units.map((String unit) {
        return DropdownMenuItem<String>(
          value: unit,
          child: Text(unit),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) => value == '--' ? 'Bitte eine Einheit wählen' : null,
    );
  }

  Widget _descriptionField() {
    return TextFormField(
      decoration: const InputDecoration(labelText: 'Beschreibung'),
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.sentences,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Bitte eine Beschreibung eingeben';
        }
        return null;
      },
      onSaved: (value) => description = value!,
    );
  }

  Widget _doubleField(Function(double) onSave, String labelText) {
    return TextFormField(
      decoration: InputDecoration(labelText: labelText),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Bitte eine Zahl eingeben';
        }
        final doubleValue = double.tryParse(value);
        if (doubleValue == null) {
          return 'Bitte eine gültige Zahl eingeben';
        }
        return null;
      },
      onSaved: (value) => onSave(double.parse(value!)),
    );
  }

  Widget _dateField(
      String labelText, DateTime? selectedDate, Function(DateTime?) onSaved) {
    // Create a controller to manage the text field's content
    TextEditingController controller = TextEditingController(
      text: selectedDate != null
          ? selectedDate
              .toString()
              .split(' ')[0] // Format the date as YYYY-MM-DD
          : '',
    );

    return TextFormField(
      controller:
          controller, // Use the controller to manage the text field content
      readOnly: true, // Prevent direct editing, only pick date
      decoration: InputDecoration(
        labelText: labelText,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        border: const OutlineInputBorder(),
      ),
      onTap: () async {
        // Show the date picker when the field is tapped
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onSaved(picked); // Call the onSaved function with the picked date

          // Update the controller's text with the selected date
          controller.text =
              picked.toString().split(' ')[0]; // Format as YYYY-MM-DD
        }
      },
      validator: (String? value) {
        if (value == null || value.isEmpty) {
          return 'Bitte ein Datum auswählen';
        }
        // Try to parse the string to DateTime to check if it's a valid date format
        try {
          DateTime.parse(value); // If this fails, it throws an error
        } catch (e) {
          return 'Ungültiges Datumsformat';
        }
        // If both dates are set, the usage date must be after the purchase date
        if (purchaseDate != null && usageDate != null) {
          if (usageDate!.isBefore(purchaseDate!)) {
            return 'Verbrauchsdatum muss nach dem Kaufdatum liegen';
          }
        }

        return null; // Return null if the date is valid
      },
    );
  }
}
