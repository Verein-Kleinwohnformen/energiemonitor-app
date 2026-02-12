import 'package:flutter/material.dart';
import 'package:kwf_energiemonitor/metering_point.dart';
import 'package:intl/intl.dart';

/// Widget für eine einzelne Messpunkt-Karte
class MeteringPointCard extends StatefulWidget {
  final MeteringPoint meteringPoint;

  const MeteringPointCard({
    super.key,
    required this.meteringPoint,
  });

  @override
  State<MeteringPointCard> createState() => _MeteringPointCardState();
}

class _MeteringPointCardState extends State<MeteringPointCard> {
  bool _isExpanded = false;

  String _formatLastSeen(int timestamp) {
    if (timestamp == 0) return 'Keine Daten';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Gerade eben';
    } else if (difference.inHours < 1) {
      return 'vor ${difference.inMinutes} Min.';
    } else if (difference.inHours < 24) {
      return 'vor ${difference.inHours} Std.';
    } else if (difference.inDays < 7) {
      return 'vor ${difference.inDays} Tag${difference.inDays > 1 ? 'en' : ''}';
    } else {
      return DateFormat('dd.MM.yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info =
        MeteringPointDefinitions.getInfo(widget.meteringPoint.meteringPointId);
    final categoryColor =
        MeteringPointDefinitions.getCategoryColor(info.category);

    return Card(
      color: categoryColor,
      elevation: 2,
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header mit ID und Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Messpunkt-ID
                  Text(
                    widget.meteringPoint.meteringPointId,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  // Online/Offline Status (nur für nicht-manuelle Punkte)
                  if (widget.meteringPoint.hasOnlineStatus)
                    _buildStatusIndicator(),
                ],
              ),
              const SizedBox(height: 6),

              // Name
              Text(
                info.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Einheit (falls vorhanden)
              if (info.unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '[${info.unit}]',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
                ),

              const SizedBox(height: 6),

              // Sensor-Typen (immer anzeigen, wenn vorhanden)
              if (widget.meteringPoint.sensorTypes.isNotEmpty)
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: widget.meteringPoint.sensorTypes
                      .map((sensor) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              sensor,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.black.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ))
                      .toList(),
                ),

              const SizedBox(height: 6),

              // Letzter Zeitpunkt
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: Colors.black.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatLastSeen(widget.meteringPoint.lastSeen),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ),
                  // Expand/Collapse Icon
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Colors.black.withOpacity(0.6),
                  ),
                ],
              ),

              // Warnung bei Offline-Status
              if (widget.meteringPoint.isOffline)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.orange.shade700,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: Colors.orange.shade900,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Offline',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Erweiterte Details
              if (_isExpanded) ...[
                const Divider(height: 16),

                // Sensoren
                if (widget.meteringPoint.sensorTypes.isNotEmpty) ...[
                  Text(
                    'Sensoren',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...widget.meteringPoint.sensorTypes.map((sensor) => Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.sensors,
                              size: 10,
                              color: Colors.black.withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              sensor,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.black.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 8),
                ],

                // Werte
                if (widget.meteringPoint.valueFields.isNotEmpty) ...[
                  Text(
                    'Werte',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...widget.meteringPoint.valueFields.map((field) => Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.data_usage,
                              size: 10,
                              color: Colors.black.withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                field,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.black.withOpacity(0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (widget.meteringPoint.isOnline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.green.shade700,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              'Online',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade900,
              ),
            ),
          ],
        ),
      );
    } else if (widget.meteringPoint.isOffline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.red.shade700,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              'Offline',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade900,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Grid-Widget für alle Messpunkte
class MeteringPointsGrid extends StatelessWidget {
  final List<MeteringPoint> meteringPoints;

  const MeteringPointsGrid({
    super.key,
    required this.meteringPoints,
  });

  @override
  Widget build(BuildContext context) {
    if (meteringPoints.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(
                Icons.sensors_off,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                'Keine aktiven Messpunkte',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'In den letzten 30 Tagen wurden keine Daten empfangen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Berechne die optimale Anzahl von Spalten basierend auf der Bildschirmbreite
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
        final itemWidth =
            (constraints.maxWidth - (crossAxisCount - 1) * 8) / crossAxisCount;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: meteringPoints.map((meteringPoint) {
            return SizedBox(
              width: itemWidth,
              child: MeteringPointCard(meteringPoint: meteringPoint),
            );
          }).toList(),
        );
      },
    );
  }
}
