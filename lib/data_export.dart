import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kwf_energiemonitor/user.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;

class DataExportPage extends StatefulWidget {
  const DataExportPage({super.key});

  @override
  State<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends State<DataExportPage> {
  DateTime? startDate;
  DateTime? endDate;
  bool isLoading = false;
  String? errorMessage;

  final String apiBaseUrl =
      'https://energiemonitor-api-325255315766.europe-west6.run.app';

  @override
  void initState() {
    super.initState();
    // Default: Yesterday as end date, 30 days back as start date (to stay under 31-day API limit)
    final now = DateTime.now();
    endDate = now.subtract(const Duration(days: 1)); // Yesterday
    startDate =
        endDate!.subtract(const Duration(days: 30)); // 30 days before yesterday
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Startdatum wählen',
    );

    if (picked != null && picked != startDate) {
      setState(() {
        startDate = picked;
        errorMessage = null;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Enddatum wählen',
    );

    if (picked != null && picked != endDate) {
      setState(() {
        endDate = picked;
        errorMessage = null;
      });
    }
  }

  bool _validateDateRange() {
    if (startDate == null || endDate == null) {
      setState(() {
        errorMessage = 'Bitte wähle Start- und Enddatum';
      });
      return false;
    }

    if (endDate!.isBefore(startDate!)) {
      setState(() {
        errorMessage = 'Enddatum muss nach Startdatum liegen';
      });
      return false;
    }

    final daysDifference = endDate!.difference(startDate!).inDays;
    if (daysDifference >= 31) {
      setState(() {
        errorMessage =
            'Maximaler Zeitraum: 31 Tage (aktuell: ${daysDifference + 1} Tage)';
      });
      return false;
    }

    return true;
  }

  Future<void> _downloadData() async {
    if (!_validateDateRange()) return;

    final activeMonitor = AppUser().activeMonitor;
    final apiKey = AppUser().activeMonitorApiKey;

    if (activeMonitor == null) {
      setState(() {
        errorMessage = 'Kein Monitor zugewiesen';
      });
      return;
    }

    if (apiKey == null || apiKey.isEmpty) {
      setState(() {
        errorMessage = 'Kein API-Key für diesen Monitor verfügbar';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate!);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate!);

      final url = Uri.parse(
          '$apiBaseUrl/export?start_date=$startDateStr&end_date=$endDateStr');

      final response = await http.get(
        url,
        headers: {'KWF-Device-Key': apiKey},
      );

      if (response.statusCode == 200) {
        // Success - trigger download
        final filename =
            'energiemonitor_${activeMonitor.id}_${startDateStr}_$endDateStr.xlsx';
        _downloadFileWeb(response.bodyBytes, filename);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Daten erfolgreich heruntergeladen'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (response.statusCode == 400) {
        setState(() {
          errorMessage = 'Ungültige Anfrage. Prüfe den Zeitraum.';
        });
      } else if (response.statusCode == 401) {
        setState(() {
          errorMessage = 'Authentifizierung fehlgeschlagen. API-Key ungültig.';
        });
      } else if (response.statusCode == 500) {
        setState(() {
          errorMessage = 'Server-Fehler. Bitte später erneut versuchen.';
        });
      } else {
        setState(() {
          errorMessage = 'Fehler beim Download (Code: ${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Netzwerk-Fehler: ${e.toString()}';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _downloadFileWeb(List<int> bytes, String filename) {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final activeMonitor = AppUser().activeMonitor;
    final hasApiKey = AppUser().activeMonitorApiKey != null;
    final isLoggedIn = AppUser().isLoggedIn;

    if (!isLoggedIn) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Bitte melde dich an, um Daten herunterzuladen',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Monitor Info Card
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: Icon(
                  Icons.monitor_heart,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                title: Text(
                  'Aktueller Monitor',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                subtitle: activeMonitor != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            activeMonitor.tinyhouseName,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                          Text(
                            activeMonitor.tinyhouseLocation,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withOpacity(0.8),
                            ),
                          ),
                          Text(
                            'ID: ${activeMonitor.id}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withOpacity(0.8),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Kein Monitor zugewiesen',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                trailing: AppUser().hasMultipleMonitors
                    ? IconButton(
                        icon: Icon(
                          Icons.swap_horiz,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        tooltip: 'Monitor wechseln',
                        onPressed: () {
                          setState(() {
                            AppUser().changeActiveMonitorRead();
                          });
                        },
                      )
                    : null,
              ),
            ),

            const SizedBox(height: 24),

            // Date Selection
            Text(
              'Zeitraum wählen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectStartDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      startDate != null
                          ? DateFormat('dd.MM.yyyy').format(startDate!)
                          : 'Startdatum',
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.arrow_forward),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectEndDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      endDate != null
                          ? DateFormat('dd.MM.yyyy').format(endDate!)
                          : 'Enddatum',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Info text
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Maximaler Zeitraum: 31 Tage',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
              ],
            ),

            if (startDate != null && endDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    Text(
                      'Gewählter Zeitraum: ${endDate!.difference(startDate!).inDays + 1} Tage',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Error message
            if (errorMessage != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (errorMessage != null) const SizedBox(height: 16),

            // Download button
            FilledButton.icon(
              onPressed: (!hasApiKey || isLoading) ? null : _downloadData,
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download),
              label: Text(
                isLoading ? 'Wird heruntergeladen...' : 'Daten herunterladen',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            if (!hasApiKey && activeMonitor != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '⚠️ Kein API-Key für diesen Monitor verfügbar. Bitte wende dich an den Administrator.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 24),

            // Info section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Über den Datenexport',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.insert_drive_file, 'Dateiformat',
                        'Excel (.xlsx)'),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                        Icons.layers, 'Struktur', 'Separate Tabs pro Sensor'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.table_chart, 'Inhalt',
                        'Timestamp, Datum/Zeit, Messpunkt, Sensor-Werte'),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                        Icons.timer, 'Zeitraum', 'Maximal 31 Tage pro Export'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodySmall,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
