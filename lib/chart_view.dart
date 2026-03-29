import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:kwf_energiemonitor/user.dart';
import 'package:kwf_energiemonitor/metering_point.dart';
import 'package:kwf_energiemonitor/metering_point_service.dart';
import 'package:kwf_energiemonitor/telemetry.dart';
import 'package:kwf_energiemonitor/telemetry_service.dart';

class ChartView extends StatefulWidget {
  const ChartView({super.key});

  @override
  State<ChartView> createState() => _ChartViewState();
}

class _ChartViewState extends State<ChartView> {
  final MeteringPointService _meteringPointService = MeteringPointService();
  final TelemetryService _telemetryService = TelemetryService();

  List<MeteringPoint> _meteringPoints = [];
  MeteringPoint? _selectedMeteringPoint;
  String? _selectedSensorId;
  Set<String> _selectedValues = {};
  List<TelemetryDataPoint>? _chartData;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isManualChart = false;

  // Zoom / pan state
  double _zoomFactor = 1.0;
  double _panOffset = 0.0;
  double _scaleStartFactor = 1.0;
  double _chartWidth = 300.0;

  // Time range selection
  String _timeRange = 'heute'; // for automatic: 'heute', 'woche', 'custom'
  // for manual: 'monat', 'jahr', 'zweijahre'
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Check if selected metering point is manual
  bool get _isManualMeteringPoint =>
      _selectedMeteringPoint?.meteringPointId.startsWith('M') ?? false;

  @override
  void initState() {
    super.initState();
    _loadMeteringPoints();
  }

  Future<void> _loadMeteringPoints() async {
    if (!AppUser().isLoggedIn || AppUser().activeMonitor == null) {
      return;
    }

    final meteringPoints = await _meteringPointService
        .fetchMeteringPoints(AppUser().activeMonitor!.id);
    setState(() {
      _meteringPoints = meteringPoints;
      // Reset selection when metering points change
      _selectedMeteringPoint = null;
      _selectedSensorId = null;
      _selectedValues.clear();
      _chartData = null;
    });
  }

  DateTimeRange _getDateRange() {
    final now = DateTime.now();

    if (_isManualMeteringPoint) {
      // Manual metering points have different time ranges
      switch (_timeRange) {
        case 'monat':
          final start = DateTime(now.year, now.month, 1, 0, 0, 0);
          final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          return DateTimeRange(start: start, end: end);
        case 'jahr':
          final start = DateTime(now.year, 1, 1, 0, 0, 0);
          final end = DateTime(now.year, 12, 31, 23, 59, 59);
          return DateTimeRange(start: start, end: end);
        case 'zweijahre':
          final start = DateTime(now.year - 1, 1, 1, 0, 0, 0);
          final end = DateTime(now.year, 12, 31, 23, 59, 59);
          return DateTimeRange(start: start, end: end);
        default:
          final start = DateTime(now.year, now.month, 1, 0, 0, 0);
          final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          return DateTimeRange(start: start, end: end);
      }
    } else {
      // Automatic metering points
      switch (_timeRange) {
        case 'heute':
          final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
          final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
          return DateTimeRange(start: start, end: end);
        case '2tage':
          final start2 = DateTime(now.year, now.month, now.day - 1, 0, 0, 0);
          return DateTimeRange(start: start2, end: now);
        case '3tage':
          final start3 = DateTime(now.year, now.month, now.day - 2, 0, 0, 0);
          return DateTimeRange(start: start3, end: now);
        case 'woche':
          final end = now;
          final start = now.subtract(const Duration(days: 7));
          return DateTimeRange(start: start, end: end);
        case 'custom':
          if (_customStartDate != null && _customEndDate != null) {
            return DateTimeRange(
                start: _customStartDate!, end: _customEndDate!);
          }
          // Fallback to today
          final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
          final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
          return DateTimeRange(start: start, end: end);
        default:
          final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
          final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
          return DateTimeRange(start: start, end: end);
      }
    }
  }

  /// Applies forward-fill to a list of manual data points.
  /// Inserts a synthetic point at [start] if [preEntry] is available,
  /// and appends a synthetic point at [end] with the last known value.
  List<TelemetryDataPoint> _applyForwardFill(
    List<TelemetryDataPoint> real,
    TelemetryDataPoint? preEntry,
    DateTime start,
    DateTime end,
  ) {
    if (real.isEmpty && preEntry == null) return [];

    final result = <TelemetryDataPoint>[];

    // Synthetic start point from the last known value before the range
    if (preEntry != null) {
      result.add(TelemetryDataPoint(
        timestamp: start.millisecondsSinceEpoch,
        values: Map<String, double>.from(preEntry.values),
        meteringPoint: preEntry.meteringPoint,
        sensorId: preEntry.sensorId,
      ));
    }

    result.addAll(real);

    // Synthetic end point — carry the last known value to the range boundary
    final last = real.isNotEmpty ? real.last : preEntry!;
    final endMs = end.millisecondsSinceEpoch;
    if (last.timestamp < endMs) {
      result.add(TelemetryDataPoint(
        timestamp: endMs,
        values: Map<String, double>.from(last.values),
        meteringPoint: last.meteringPoint,
        sensorId: last.sensorId,
      ));
    }

    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  /// Returns the visible [minX, maxX] window based on the current zoom and pan state.
  (double, double) _computeVisibleRange(double fullMin, double fullMax) {
    if (_zoomFactor <= 1.0) return (fullMin, fullMax);
    final fullSpan = fullMax - fullMin;
    if (fullSpan <= 0) return (fullMin, fullMax);
    final visibleSpan = fullSpan / _zoomFactor;
    final maxPanOffset = 1.0 - 1.0 / _zoomFactor;
    final clampedOffset = _panOffset.clamp(0.0, maxPanOffset);
    final minX = fullMin + clampedOffset * fullSpan;
    return (minX, minX + visibleSpan);
  }

  Future<void> _loadChartData() async {
    if (_selectedMeteringPoint == null ||
        _selectedSensorId == null ||
        _selectedValues.isEmpty) {
      setState(() {
        _errorMessage =
            'Bitte wähle Messpunkt, Sensor und mindestens einen Wert aus.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dateRange = _getDateRange();

      if (_isManualMeteringPoint) {
        final data = await _telemetryService.fetchManualData(
          deviceId: AppUser().activeMonitor!.id,
          meteringPoint: _selectedMeteringPoint!.meteringPointId,
          sensorId: _selectedSensorId!,
          startDate: dateRange.start,
          endDate: dateRange.end,
        );
        final preEntry = await _telemetryService.fetchLastManualEntryBefore(
          deviceId: AppUser().activeMonitor!.id,
          meteringPoint: _selectedMeteringPoint!.meteringPointId,
          sensorId: _selectedSensorId!,
          startDate: dateRange.start,
        );
        final filled =
            _applyForwardFill(data, preEntry, dateRange.start, dateRange.end);
        setState(() {
          _chartData = filled;
          _isManualChart = true;
          _isLoading = false;
          _zoomFactor = 1.0;
          _panOffset = 0.0;
        });
      } else {
        final data = await _telemetryService.fetchTelemetryData(
          deviceId: AppUser().activeMonitor!.id,
          meteringPoint: _selectedMeteringPoint!.meteringPointId,
          sensorId: _selectedSensorId!,
          startDate: dateRange.start,
          endDate: dateRange.end,
        );
        setState(() {
          _chartData = data;
          _isManualChart = false;
          _isLoading = false;
          _zoomFactor = 1.0;
          _panOffset = 0.0;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Fehler beim Laden der Daten: $e';
        _isLoading = false;
        _chartData = null;
      });
    }
  }

  Future<void> _showCustomDateRangePicker() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );

    if (picked != null) {
      // Validate 10-day limit for automatic metering points
      final daysDiff = picked.end.difference(picked.start).inDays;

      if (!_isManualMeteringPoint && daysDiff > 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Automatische Messpunkte: Maximal 10 Tage erlaubt'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _timeRange = 'custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Box
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Wähle Monitor, Messpunkt, Zeitraum und Werte, dann klicke "Laden"',
                        style: TextStyle(color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Monitor Selection
            if (AppUser().hasMultipleMonitors)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.monitor_heart),
                  title: Text(
                      AppUser().activeMonitor?.tinyhouseName ?? 'Kein Monitor'),
                  subtitle:
                      Text(AppUser().activeMonitor?.tinyhouseLocation ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: () {
                      AppUser().changeActiveMonitorRead();
                      _loadMeteringPoints();
                    },
                  ),
                ),
              ),

            // Metering Point Selection
            if (_meteringPoints.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: DropdownButtonFormField<MeteringPoint>(
                    decoration: const InputDecoration(
                      labelText: 'Messpunkt',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedMeteringPoint,
                    items: _meteringPoints.map((mp) {
                      final info =
                          MeteringPointDefinitions.getInfo(mp.meteringPointId);
                      return DropdownMenuItem(
                        value: mp,
                        child: Text('${mp.meteringPointId} - ${info.name}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMeteringPoint = value;
                        _selectedSensorId = null;
                        _selectedValues.clear();
                        _chartData = null;
                        // Reset time range to default for new metering point type
                        if (_isManualMeteringPoint) {
                          _timeRange = 'monat';
                        } else {
                          _timeRange = 'heute';
                        }
                      });
                    },
                  ),
                ),
              ),

            // Time Range Selection (shown after metering point is selected)
            if (_selectedMeteringPoint != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Zeitraum',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_isManualMeteringPoint)
                        // Manual metering points
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Dieser Monat'),
                              selected: _timeRange == 'monat',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _timeRange = 'monat';
                                    _chartData = null;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Dieses Jahr'),
                              selected: _timeRange == 'jahr',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _timeRange = 'jahr';
                                    _chartData = null;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Zwei Jahre'),
                              selected: _timeRange == 'zweijahre',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _timeRange = 'zweijahre';
                                    _chartData = null;
                                  });
                                }
                              },
                            ),
                          ],
                        )
                      else
                        // Automatic metering points
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Heute'),
                              selected: _timeRange == 'heute',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _timeRange = 'heute';
                                    _chartData = null;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('2 Tage'),
                              selected: _timeRange == '2tage',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _timeRange = '2tage';
                                    _chartData = null;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('3 Tage'),
                              selected: _timeRange == '3tage',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _timeRange = '3tage';
                                    _chartData = null;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Diese Woche'),
                              selected: _timeRange == 'woche',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _timeRange = 'woche';
                                    _chartData = null;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: Text(_timeRange == 'custom' &&
                                      _customStartDate != null
                                  ? 'Custom (${_customStartDate!.day}.${_customStartDate!.month} - ${_customEndDate!.day}.${_customEndDate!.month})'
                                  : 'Custom (max 10 Tage)'),
                              selected: _timeRange == 'custom',
                              onSelected: (selected) async {
                                if (selected) {
                                  await _showCustomDateRangePicker();
                                }
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

            // Sensor Selection
            if (_selectedMeteringPoint != null &&
                _selectedMeteringPoint!.sensorTypes.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Sensor',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedSensorId,
                    items: _selectedMeteringPoint!.sensorTypes.map((sensor) {
                      return DropdownMenuItem(
                        value: sensor,
                        child: Text(sensor),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSensorId = value;
                        _selectedValues.clear();
                        _chartData = null;
                      });
                    },
                  ),
                ),
              ),

            // Value Selection
            if (_selectedMeteringPoint != null &&
                _selectedMeteringPoint!.valueFields.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Werte',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children:
                            _selectedMeteringPoint!.valueFields.map((field) {
                          return FilterChip(
                            label: Text(field),
                            selected: _selectedValues.contains(field),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedValues.add(field);
                                } else {
                                  _selectedValues.remove(field);
                                }
                                _chartData = null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

            // Load Button
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _loadChartData,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_isLoading ? 'Laden...' : 'Daten laden'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            // Error Message
            if (_errorMessage != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Chart Display
            if (_chartData != null && _chartData!.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Zeitgrafik - ${_selectedMeteringPoint!.meteringPointId}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_zoomFactor > 1.01)
                            IconButton(
                              icon: const Icon(Icons.zoom_out_map),
                              tooltip: 'Zoom zurücksetzen',
                              onPressed: () => setState(() {
                                _zoomFactor = 1.0;
                                _panOffset = 0.0;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          _chartWidth = constraints.maxWidth;
                          return GestureDetector(
                            onScaleStart: (details) {
                              _scaleStartFactor = _zoomFactor;
                            },
                            onScaleUpdate: (details) {
                              setState(() {
                                _zoomFactor =
                                    (_scaleStartFactor * details.scale)
                                        .clamp(1.0, 20.0);
                                if (_zoomFactor > 1.0) {
                                  final maxPan = 1.0 - 1.0 / _zoomFactor;
                                  _panOffset = (_panOffset -
                                          (details.focalPointDelta.dx /
                                                  _chartWidth) *
                                              (1.0 / _zoomFactor))
                                      .clamp(0.0, maxPan);
                                } else {
                                  _panOffset = 0.0;
                                }
                              });
                            },
                            child: SizedBox(
                              height: 300,
                              child: _buildChart(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

            // No Data Message
            if (_chartData != null && _chartData!.isEmpty)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Keine Daten im gewählten Zeitraum gefunden',
                          style: TextStyle(color: Colors.black87),
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

  Widget _buildChart() {
    if (_chartData == null || _chartData!.isEmpty || _selectedValues.isEmpty) {
      return const Center(child: Text('Keine Daten zum Anzeigen'));
    }

    if (_isManualChart) {
      return _buildManualChart();
    }

    // Prepare chart data
    final List<LineChartBarData> lineChartData = [];
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    int colorIndex = 0;
    for (final valueField in _selectedValues) {
      final spots = <FlSpot>[];

      for (int i = 0; i < _chartData!.length; i++) {
        final point = _chartData![i];
        final value = point.values[valueField];
        if (value != null) {
          spots.add(FlSpot(i.toDouble(), value));
        }
      }

      if (spots.isNotEmpty) {
        lineChartData.add(
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: colors[colorIndex % colors.length],
            barWidth: 2,
            isStrokeCapRound: true,
            dotData:
                FlDotData(show: _chartData!.length < 50 || _zoomFactor >= 3.0),
            belowBarData: BarAreaData(show: false),
          ),
        );
        colorIndex++;
      }
    }

    // Calculate min/max for Y-axis
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final point in _chartData!) {
      for (final valueField in _selectedValues) {
        final value = point.values[valueField];
        if (value != null) {
          if (value < minY) minY = value;
          if (value > maxY) maxY = value;
        }
      }
    }

    // Add 10% padding
    final range = maxY - minY;
    minY -= range * 0.1;
    maxY += range * 0.1;

    // Compute visible X window for zoom/pan (index-based)
    final fullMaxX = (_chartData!.length - 1).toDouble();
    final (visMinX, visMaxX) = _computeVisibleRange(0.0, fullMaxX);
    final visibleIntervalRaw = ((visMaxX - visMinX) / 6).ceilToDouble();
    final visibleInterval = visibleIntervalRaw < 1.0 ? 1.0 : visibleIntervalRaw;

    return LineChart(
      LineChartData(
        lineBarsData: lineChartData,
        minX: visMinX,
        maxX: visMaxX,
        minY: minY,
        maxY: maxY,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: visibleInterval,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _chartData!.length) {
                  final point = _chartData![index];
                  final showDate = _timeRange != 'heute';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      point.formatForChart(showDate: showDate),
                      style: const TextStyle(fontSize: 9),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: (maxY - minY) / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade400, width: 1),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= 0 && index < _chartData!.length) {
                  final point = _chartData![index];
                  final valueField =
                      _selectedValues.elementAt(touchedSpots.indexOf(spot));
                  return LineTooltipItem(
                    '${point.formatDateTime()}\n$valueField: ${spot.y.toStringAsFixed(2)}',
                    TextStyle(
                        color: spot.bar.color, fontWeight: FontWeight.bold),
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildManualChart() {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    // Compute full X range from timestamps
    final fullMinX = _chartData!.first.timestamp.toDouble();
    final fullMaxX = _chartData!.last.timestamp.toDouble();

    // Apply zoom/pan to get the visible window
    final (minX, maxX) = _computeVisibleRange(fullMinX, fullMaxX);

    // Build one step-line series per selected value field
    final List<LineChartBarData> lineChartData = [];
    int colorIndex = 0;

    double maxY = 0;

    for (final valueField in _selectedValues) {
      final spots = <FlSpot>[];

      for (final point in _chartData!) {
        final value = point.values[valueField];
        if (value != null) {
          spots.add(FlSpot(point.timestamp.toDouble(), value));
          if (value > maxY) maxY = value;
        }
      }

      if (spots.isNotEmpty) {
        lineChartData.add(
          LineChartBarData(
            spots: spots,
            isCurved: false,
            isStepLineChart: true,
            color: colors[colorIndex % colors.length],
            barWidth: 2,
            isStrokeCapRound: false,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        );
        colorIndex++;
      }
    }

    // X-axis label formatter — interval based on visible window
    final dateFormat = DateFormat('dd.MM.yy');
    final xInterval = (maxX - minX) > 0 ? (maxX - minX) / 5 : 1.0;

    return LineChart(
      LineChartData(
        lineBarsData: lineChartData,
        minX: minX,
        maxX: maxX,
        minY: 0,
        maxY: maxY * 1.15,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    dateFormat.format(dt),
                    style: const TextStyle(fontSize: 9),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: maxY > 0 ? maxY * 1.15 / 5 : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.shade300, strokeWidth: 1);
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade400, width: 1),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                // Find the data point by timestamp
                TelemetryDataPoint? point;
                try {
                  point = _chartData!.firstWhere(
                    (p) => (p.timestamp.toDouble() - spot.x).abs() < 1,
                  );
                } catch (_) {
                  point = null;
                }
                final valueField =
                    _selectedValues.elementAt(touchedSpots.indexOf(spot));
                final dateStr = point != null
                    ? DateFormat('dd.MM.yyyy').format(point.dateTime)
                    : spot.x.toInt().toString();
                return LineTooltipItem(
                  '$dateStr\n$valueField: ${spot.y.toStringAsFixed(2)}',
                  TextStyle(color: spot.bar.color, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
