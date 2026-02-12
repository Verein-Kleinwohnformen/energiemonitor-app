import 'package:flutter/material.dart';
import 'package:kwf_energiemonitor/metering_point.dart';
import 'package:intl/intl.dart';

/// Widget für eine einzelne Messpunkt-Karte
class MeteringPointCard extends StatelessWidget {
  final MeteringPoint meteringPoint;

  const MeteringPointCard({
    super.key,
    required this.meteringPoint,
  });

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
        MeteringPointDefinitions.getInfo(meteringPoint.meteringPointId);
    final categoryColor =
        MeteringPointDefinitions.getCategoryColor(info.category);

    return Card(
      color: categoryColor,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
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
                  meteringPoint.meteringPointId,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                // Online/Offline Status (nur für nicht-manuelle Punkte)
                if (meteringPoint.hasOnlineStatus) _buildStatusIndicator(),
              ],
            ),
            const SizedBox(height: 8),

            // Name
            Text(
              info.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),

            // Einheit (falls vorhanden)
            if (info.unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '[${info.unit}]',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Letzter Zeitpunkt
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.black.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatLastSeen(meteringPoint.lastSeen),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),

            // Warnung bei Offline-Status
            if (meteringPoint.isOffline)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
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
                        size: 16,
                        color: Colors.orange.shade900,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (meteringPoint.isOnline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.shade700,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Online',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade900,
              ),
            ),
          ],
        ),
      );
    } else if (meteringPoint.isOffline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red.shade700,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Offline',
              style: TextStyle(
                fontSize: 11,
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

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: meteringPoints.length,
      itemBuilder: (context, index) {
        return MeteringPointCard(meteringPoint: meteringPoints[index]);
      },
    );
  }
}
