import 'package:flutter/widgets.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/typograpthy.dart';

class PsLabel extends StatelessWidget {
  const PsLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 200,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(200, 40),
            painter: PsLabelPainter(),
          ),
          SizedBox(
            height: 40,
            width: 200,
            child: Column(
              children: [
                Expanded(child: BodyText(text: "Size", textAlign: TextAlign.center,)),
                Expanded(child: BodyText(text: "Mahsulot", textAlign: TextAlign.center,)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PsLabelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textSecondary
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(PsLabelPainter oldDelegate) => false;

  @override
  bool shouldRebuildSemantics(PsLabelPainter oldDelegate) => false;
}
