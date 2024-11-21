import 'package:flutter/material.dart';
import 'package:kwf_energiemonitor/energy.dart';
import 'package:intl/intl.dart'; // For formatting dates

class EnergyCard extends StatelessWidget {
  const EnergyCard(this.energy, {super.key});

  final Energy energy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final image = AssetImage(energy.imageString);
    final formattedDate = DateFormat("d.M.yyyy").format(energy.purchaseDate);
    final daysAgo = DateTime.now().difference(energy.purchaseDate).inDays;
    final totalQuantity = energy.purchaseQuantity + energy.leftoverQuantity;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Image and Type
            Column(
              children: [
                Image(image: image, width: 100, height: 100),
                const SizedBox(height: 8),
                Text(energy.formattedDescription, style: theme.bodyMedium),
              ],
            ),
            const SizedBox(width: 16),
            // Main Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    energy.description ?? 'Keine Beschreibung',
                    style: theme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  // Date and Days Ago
                  Row(
                    children: [
                      // Black tag for the formatted date
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          formattedDate,
                          style: theme.bodySmall?.copyWith(color: Colors.white),
                        ),
                      ),
                      const SizedBox(
                          width:
                              8), // Spacing between the tag and the "vor x Tagen" text
                      // Grey text for "vor x Tagen"
                      Text(
                        'vor ${daysAgo} Tagen',
                        style: theme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Quantities
                  Text(
                    'Total: $totalQuantity',
                    style:
                        theme.headlineSmall?.copyWith(color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 4),
                  Text('Gekauft: ${energy.purchaseQuantity}'),
                  Text('Übrig: ${energy.leftoverQuantity}'),
                ],
              ),
            ),
            // Delete Button
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                // Handle deletion
              },
            ),
          ],
        ),
      ),
    );
  }
}
