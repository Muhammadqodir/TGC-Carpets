import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgc_client/features/labeling/presentation/widgets/label_undo_toast.dart';

void main() {
  Future<void> pump(WidgetTester tester, LabelUndoToastStatus status, {VoidCallback? onUndo}) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LabelUndoToast(
            label: '1568 200×300',
            status: status,
            duration: const Duration(seconds: 15),
            onUndo: onUndo ?? () {},
            onClose: () {},
          ),
        ),
      ));

  testWidgets('offers the undo with what was printed and a bar running down', (tester) async {
    var undone = 0;
    await pump(tester, LabelUndoToastStatus.offered, onUndo: () => undone++);

    expect(find.text('Chop etildi'), findsOneWidget);
    expect(find.text('1568 200×300'), findsOneWidget);
    double bar() => tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value!;
    expect(bar(), 1);
    await tester.pump(const Duration(seconds: 5));
    expect(bar(), closeTo(2 / 3, 0.01));

    await tester.tap(find.text('Bekor qilish'));
    expect(undone, 1);
  });

  testWidgets('after the undo it says so and asks to throw the label away', (tester) async {
    await pump(tester, LabelUndoToastStatus.undone);

    expect(find.text('Bekor qilindi: 1568 200×300'), findsOneWidget);
    expect(find.textContaining('yo\'q qiling'), findsOneWidget);
    expect(find.text('Bekor qilish'), findsNothing, reason: 'nothing left to undo');
  });
}
