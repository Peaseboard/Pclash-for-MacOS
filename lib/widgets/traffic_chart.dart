import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/traffic_stats.dart';

class TrafficChart extends StatelessWidget {
  final List<TrafficStats> history;
  final Color upColor;
  final Color downColor;

  const TrafficChart({
    super.key,
    required this.history,
    this.upColor = Colors.blue,
    this.downColor = Colors.green,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return SizedBox(
        height: 150,
        child: Center(child: Text('Waiting for traffic data...', style: TextStyle(color: Colors.grey[600]))),
      );
    }

    final upSpots = _generateSpots(history.map((e) => e.up.toDouble()).toList());
    final downSpots = _generateSpots(history.map((e) => e.down.toDouble()).toList());
    final maxY = _calculateMaxY(upSpots, downSpots);

    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _formatBytes(value.toInt()),
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: history.length.toDouble() - 1,
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: upSpots,
              isCurved: true,
              color: upColor,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: upColor.withOpacity(0.1),
              ),
            ),
            LineChartBarData(
              spots: downSpots,
              isCurved: true,
              color: downColor,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: downColor.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _generateSpots(List<double> data) {
    return data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
  }

  double _calculateMaxY(List<FlSpot> up, List<FlSpot> down) {
    double max = 0;
    for (final spot in [...up, ...down]) {
      if (spot.y > max) max = spot.y;
    }
    return max > 0 ? max * 1.2 : 1000;
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
