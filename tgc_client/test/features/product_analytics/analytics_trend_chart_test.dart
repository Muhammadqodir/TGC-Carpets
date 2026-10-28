import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgc_client/features/product_analytics/domain/entities/product_analytics_entity.dart';
import 'package:tgc_client/features/product_analytics/presentation/widgets/analytics_trend_chart.dart';

void main() {
  final trend = [
    for (var d = 1; d <= 28; d++)
      if (d % 6 != 0)
        AnalyticsTrendPoint(
          label: '2026-10-${d.toString().padLeft(2, '0')}',
          ordersCount: d % 4 + 1,
          totalQuantity: 40 + d * 3 % 50,
          totalSqm: (40 + d * 3 % 50) * 4.5,
        ),
  ];

  for (final width in [360.0, 1200.0]) {
    for (final metric in AnalyticsMetric.values) {
      testWidgets('order trend bars at ${width.toInt()}px, ${metric.name}', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: AnalyticsTrendChart(
                trend: trend,
                trendBy: 'day',
                periodFrom: '2026-09-29',
                periodTo: '2026-10-28',
                metric: metric,
              ),
            ),
          ),
        ));

        expect(tester.takeException(), isNull);
        // A single series has no legend.
        expect(find.text('Buyurtmalar'), findsNothing);
      });
    }
  }
}
