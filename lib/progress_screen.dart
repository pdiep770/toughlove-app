import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
import 'tracked_lift_series.dart';

// Validated categorical palette (dataviz skill, references/palette.md), slots 1-3.
// Light/dark pairs, in fixed order -- never cycled, never reassigned by rank.
const _seriesColorsLight = [
  Color(0xFF2A78D6), // blue -- Barbell Squat
  Color(0xFFEB6834), // orange -- Barbell Bench Press
  Color(0xFF1BAF7A), // aqua -- Deadlift
];
const _seriesColorsDark = [
  Color(0xFF3987E5),
  Color(0xFFD95926),
  Color(0xFF199E70),
];

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => ProgressScreenState();
}

class ProgressScreenState extends State<ProgressScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  /// Called by MainTabScreen when this tab is selected, since IndexedStack
  /// keeps this widget's state alive across tab switches -- initState alone
  /// wouldn't pick up a workout logged while on a different tab.
  Future<void> reload() => _loadLogs();

  Future<void> _loadLogs() async {
    final logs = await FirestoreService().getLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final series = extractTrackedLiftSeries(_logs);
    final colorScheme = Theme.of(context).colorScheme;
    final seriesColors = Theme.of(context).brightness == Brightness.dark
        ? _seriesColorsDark
        : _seriesColorsLight;

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: _logs.isEmpty
          ? _EmptyState(colorScheme: colorScheme)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (series.isNotEmpty) ...[
                  Text('Tracked lifts', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _WeightTrendChart(series: series, seriesColors: seriesColors),
                  const SizedBox(height: 24),
                ],
                Text('Workout history', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ..._logs.map((log) => _HistoryCard(log: log)),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;

  const _EmptyState({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Log a workout to start tracking your progress here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> log;

  const _HistoryCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final loggedAt = log['loggedAt'];
    final date = loggedAt is Timestamp ? loggedAt.toDate() : null;
    final exercises = (log['exercises'] as List?) ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log['dayLabel'] ?? 'Workout', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    date != null ? '${date.month}/${date.day}/${date.year}' : '',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(
              '${exercises.length} exercises',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightTrendChart extends StatelessWidget {
  final Map<String, List<WeightPoint>> series;
  final List<Color> seriesColors;

  const _WeightTrendChart({required this.series, required this.seriesColors});

  // fl_chart's automatic tick spacing has no notion of a calendar day -- left to
  // itself it can place several ticks within the same day, which all render the
  // same "month/day" label. Flooring the interval at one day (and otherwise aiming
  // for a handful of ticks across the full range) guarantees every rendered tick
  // lands on a distinct calendar date.
  static const _oneDayMs = 86400000.0;
  static const _maxTicks = 5;

  double _tickInterval(double minX, double maxX) {
    final span = maxX - minX;
    if (span <= 0) return _oneDayMs;
    final rawInterval = span / _maxTicks;
    return rawInterval < _oneDayMs ? _oneDayMs : rawInterval;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final gridColor = colorScheme.outlineVariant.withValues(alpha: 0.4);

    final orderedEntries = trackedLiftNames
        .where(series.containsKey)
        .map((name) => MapEntry(name, series[name]!))
        .toList();

    final allDates = orderedEntries.expand((e) => e.value).map((p) => p.date).toList();
    final minX = allDates.map((d) => d.millisecondsSinceEpoch).reduce((a, b) => a < b ? a : b).toDouble();
    final maxX = allDates.map((d) => d.millisecondsSinceEpoch).reduce((a, b) => a > b ? a : b).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (var i = 0; i < orderedEntries.length; i++)
              _LegendEntry(
                color: seriesColors[trackedLiftNames.indexOf(orderedEntries[i].key)],
                label: orderedEntries[i].key,
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX == minX ? minX + 1 : maxX,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: null,
                getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: _tickInterval(minX, maxX),
                    getTitlesWidget: (value, meta) {
                      final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${date.month}/${date.day}',
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => colorScheme.inverseSurface,
                  getTooltipItems: (spots) => spots.map((spot) {
                    final name = orderedEntries[spot.barIndex].key;
                    return LineTooltipItem(
                      '$name\n${spot.y.toStringAsFixed(0)} lbs',
                      TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                for (var i = 0; i < orderedEntries.length; i++)
                  LineChartBarData(
                    spots: orderedEntries[i]
                        .value
                        .map((p) => FlSpot(p.date.millisecondsSinceEpoch.toDouble(), p.weight))
                        .toList(),
                    isCurved: false,
                    barWidth: 2,
                    color: seriesColors[trackedLiftNames.indexOf(orderedEntries[i].key)],
                    dotData: FlDotData(
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                        radius: 4,
                        color: bar.color ?? colorScheme.primary,
                        strokeWidth: 2,
                        strokeColor: colorScheme.surface,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendEntry({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
