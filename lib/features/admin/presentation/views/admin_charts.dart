import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:icem_bus/config/theme/app_colors.dart';

class ChartDataPoint {
  final String label;
  final double value;

  ChartDataPoint(this.label, this.value);
}

// ============================================================
// LINE AREA CHART (Interactive)
// ============================================================

class LineAreaChart extends StatefulWidget {
  final List<ChartDataPoint> data;
  final String title;
  final Color primaryColor;
  final String valuePrefix;

  const LineAreaChart({
    super.key,
    required this.data,
    required this.title,
    this.primaryColor = AppColors.primaryCrimson,
    this.valuePrefix = '',
  });

  @override
  State<LineAreaChart> createState() => _LineAreaChartState();
}

class _LineAreaChartState extends State<LineAreaChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: const Center(
          child: Text('No data available', style: TextStyle(color: Color(0xFF64748B))),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              const height = 180.0;

              return GestureDetector(
                onPanStart: (details) => _updateSelection(details.localPosition, width, height),
                onPanUpdate: (details) => _updateSelection(details.localPosition, width, height),
                onPanEnd: (_) => setState(() => _selectedIndex = null),
                onTapDown: (details) => _updateSelection(details.localPosition, width, height),
                onTapUp: (_) => setState(() => _selectedIndex = null),
                child: CustomPaint(
                  size: Size(width, height),
                  painter: _LineChartPainter(
                    data: widget.data,
                    primaryColor: widget.primaryColor,
                    selectedIndex: _selectedIndex,
                    valuePrefix: widget.valuePrefix,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _updateSelection(Offset localPos, double width, double height) {
    const paddingLeft = 40.0;
    const paddingRight = 10.0;
    final chartWidth = width - paddingLeft - paddingRight;

    if (widget.data.length < 2) return;

    final xRatio = (localPos.dx - paddingLeft) / chartWidth;
    final index = (xRatio * (widget.data.length - 1)).round().clamp(0, widget.data.length - 1);

    setState(() {
      _selectedIndex = index;
    });
  }
}

class _LineChartPainter extends CustomPainter {
  final List<ChartDataPoint> data;
  final Color primaryColor;
  final int? selectedIndex;
  final String valuePrefix;

  _LineChartPainter({
    required this.data,
    required this.primaryColor,
    required this.selectedIndex,
    required this.valuePrefix,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const paddingLeft = 40.0;
    const paddingRight = 10.0;
    const paddingTop = 20.0;
    const paddingBottom = 20.0;

    final chartWidth = size.width - paddingLeft - paddingRight;
    final chartHeight = size.height - paddingTop - paddingBottom;

    final maxVal = data.map((d) => d.value).reduce(math.max);
    final minVal = 0.0;
    final range = maxVal > 0 ? maxVal : 1.0;

    // Draw Y grid lines and labels
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0;

    final textStyle = const TextStyle(color: Color(0xFF94A3B8), fontSize: 9);

    for (int i = 0; i <= 4; i++) {
      final yRatio = i / 4.0;
      final y = paddingTop + chartHeight * (1 - yRatio);
      final val = minVal + range * yRatio;

      // Grid line
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: '$valuePrefix${val.toStringAsFixed(0)}',
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(paddingLeft - tp.width - 6, y - tp.height / 2));
    }

    // Coordinates of data points
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = paddingLeft + (i / (data.length - 1)) * chartWidth;
      final y = paddingTop + chartHeight * (1 - (data[i].value / range));
      points.add(Offset(x, y));
    }

    // Draw Area Fill (Gradient)
    if (points.isNotEmpty) {
      final fillPath = Path()
        ..moveTo(points.first.dx, paddingTop + chartHeight)
        ..lineTo(points.first.dx, points.first.dy);

      for (int i = 1; i < points.length; i++) {
        fillPath.lineTo(points[i].dx, points[i].dy);
      }

      fillPath.lineTo(points.last.dx, paddingTop + chartHeight);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primaryColor.withOpacity(0.3),
            primaryColor.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTRB(paddingLeft, paddingTop, size.width - paddingRight, paddingTop + chartHeight));

      canvas.drawPath(fillPath, fillPaint);

      // Draw Stroke Line
      final strokePaint = Paint()
        ..color = primaryColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final strokePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        strokePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(strokePath, strokePaint);
    }

    // Draw X labels
    for (int i = 0; i < data.length; i++) {
      if (data.length > 6 && i % (data.length / 4).ceil() != 0 && i != data.length - 1) {
        continue;
      }
      final x = points[i].dx;
      final y = size.height - paddingBottom + 4;

      final tp = TextPainter(
        text: TextSpan(text: data[i].label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y));
    }

    // Draw Interactive Tooltip
    if (selectedIndex != null && selectedIndex! < points.length) {
      final selectedPoint = points[selectedIndex!];
      final item = data[selectedIndex!];

      // Vertical indicator line
      final indicatorPaint = Paint()
        ..color = primaryColor.withOpacity(0.4)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(selectedPoint.dx, paddingTop),
        Offset(selectedPoint.dx, paddingTop + chartHeight),
        indicatorPaint,
      );

      // Circle marker
      final markerInner = Paint()..color = primaryColor;
      final markerOuter = Paint()..color = Colors.white;
      canvas.drawCircle(selectedPoint, 5, markerOuter);
      canvas.drawCircle(selectedPoint, 3, markerInner);

      // Tooltip Box
      final tooltipText = '$valuePrefix${item.value.toStringAsFixed(0)}';
      final tooltipLabel = item.label;

      final tpTitle = TextPainter(
        text: TextSpan(
          text: '$tooltipLabel: ',
          style: const TextStyle(color: Colors.white70, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final tpVal = TextPainter(
        text: TextSpan(
          text: tooltipText,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final boxWidth = tpTitle.width + tpVal.width + 12;
      final boxHeight = 22.0;

      double boxX = selectedPoint.dx - boxWidth / 2;
      if (boxX < paddingLeft) boxX = paddingLeft;
      if (boxX + boxWidth > size.width - paddingRight) boxX = size.width - paddingRight - boxWidth;

      double boxY = selectedPoint.dy - boxHeight - 8;
      if (boxY < paddingTop) boxY = selectedPoint.dy + 8;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(boxX, boxY, boxWidth, boxHeight),
        const Radius.circular(6),
      );

      final boxPaint = Paint()..color = const Color(0xFF0F172A);
      canvas.drawRRect(rect, boxPaint);

      tpTitle.paint(canvas, Offset(boxX + 6, boxY + (boxHeight - tpTitle.height) / 2));
      tpVal.paint(canvas, Offset(boxX + 6 + tpTitle.width, boxY + (boxHeight - tpVal.height) / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex || oldDelegate.data != data;
  }
}

// ============================================================
// DONUT PIE CHART
// ============================================================

class DonutChartWidget extends StatelessWidget {
  final Map<String, double> data;
  final String title;
  final List<Color> colors;

  const DonutChartWidget({
    super.key,
    required this.data,
    required this.title,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold(0.0, (sum, val) => sum + val);

    if (total == 0) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: const Center(
          child: Text('No data available', style: TextStyle(color: Color(0xFF64748B))),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    data: data,
                    colors: colors,
                    total: total,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(data.keys.length, (index) {
                    final key = data.keys.elementAt(index);
                    final val = data[key]!;
                    final color = colors[index % colors.length];
                    final pct = total > 0 ? (val / total * 100).toStringAsFixed(1) : '0';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              key,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                            ),
                          ),
                          Text(
                            '${val.toInt()} ($pct%)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final Map<String, double> data;
  final List<Color> colors;
  final double total;

  _DonutChartPainter({
    required this.data,
    required this.colors,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20.0
      ..strokeCap = StrokeCap.butt;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < data.length; i++) {
      final val = data.values.elementAt(i);
      final sweepAngle = (val / total) * 2 * math.pi;

      if (sweepAngle > 0) {
        paint.color = colors[i % colors.length];
        canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
        startAngle += sweepAngle;
      }
    }

    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(
            text: 'Total\n',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 10, height: 1.2),
          ),
          TextSpan(
            text: '${total.toInt()}',
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold, height: 1.2),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        size.width / 2 - textPainter.width / 2,
        size.height / 2 - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.data != data;
  }
}

// ============================================================
// HORIZONTAL BAR CHART
// ============================================================

class HorizontalBarChart extends StatelessWidget {
  final List<ChartDataPoint> data;
  final String title;
  final Color barColor;

  const HorizontalBarChart({
    super.key,
    required this.data,
    required this.title,
    this.barColor = AppColors.info,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = data.isEmpty ? 0.0 : data.map((d) => d.value).reduce(math.max);

    if (data.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: const Center(
          child: Text('No data available', style: TextStyle(color: Color(0xFF64748B))),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              final ratio = maxVal > 0 ? item.value / maxVal : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        item.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: ratio,
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    barColor.withOpacity(0.8),
                                    barColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${item.value.toInt()}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
