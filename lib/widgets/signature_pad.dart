import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// What the pad holds, and the way to get a signature out of it.
class SignaturePadController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];

  bool get isEmpty => _strokes.every((s) => s.isEmpty);

  void _start(Offset p) {
    _strokes.add([p]);
    notifyListeners();
  }

  void _extend(Offset p) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(p);
    notifyListeners();
  }

  void undo() {
    if (_strokes.isNotEmpty) _strokes.removeLast();
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  /// The signature as a PNG data URL, cropped to the ink, on a transparent
  /// background — the form the server keeps. Null when nothing is drawn.
  ///
  /// Drawn at twice the size it was signed at, so it prints cleanly; a
  /// signature is something that ends up on paper.
  Future<String?> toPngDataUrl({double pixelRatio = 2}) async {
    final points = _strokes.expand((s) => s).toList();
    if (points.isEmpty) return null;
    const pad = 12.0;
    final minX = points.map((p) => p.dx).reduce(math.min) - pad;
    final minY = points.map((p) => p.dy).reduce(math.min) - pad;
    final maxX = points.map((p) => p.dx).reduce(math.max) + pad;
    final maxY = points.map((p) => p.dy).reduce(math.max) + pad;
    final width = math.max(1.0, maxX - minX);
    final height = math.max(1.0, maxY - minY);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(pixelRatio)
      ..translate(-minX, -minY);
    _paintStrokes(canvas, _strokes);
    final image = await recorder.endRecording().toImage(
      (width * pixelRatio).ceil(),
      (height * pixelRatio).ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return null;
    return 'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}';
  }
}

/// Dark ink, as a pen draws it: round, smoothed through the midpoints.
void _paintStrokes(Canvas canvas, List<List<Offset>> strokes) {
  final ink = Paint()
    ..color = const Color(0xFF1A1614)
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  for (final stroke in strokes) {
    if (stroke.isEmpty) continue;
    if (stroke.length == 1) {
      canvas.drawCircle(stroke.first, 1.3, ink..style = PaintingStyle.fill);
      ink.style = PaintingStyle.stroke;
      continue;
    }
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (var i = 1; i < stroke.length - 1; i++) {
      final mid = Offset(
        (stroke[i].dx + stroke[i + 1].dx) / 2,
        (stroke[i].dy + stroke[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(stroke[i].dx, stroke[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(stroke.last.dx, stroke.last.dy);
    canvas.drawPath(path, ink);
  }
}

/// A pad to sign on with a finger or a stylus.
///
/// Drawn as paper — dark ink on warm white in both themes — because a
/// signature is something that gets printed, and white ink on a dark page
/// prints as nothing.
class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, required this.controller, this.height = 180});

  final SignaturePadController controller;
  final double height;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_redraw);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_redraw);
    super.dispose();
  }

  void _redraw() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF8),
              border: Border.all(color: AppColors.stroke),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Stack(
              children: [
                const Positioned(
                  left: 24,
                  right: 24,
                  bottom: 34,
                  child: _DashedLine(),
                ),
                const Positioned(
                  left: 24,
                  bottom: 12,
                  child: Text(
                    'SIGN ABOVE THE LINE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                      color: Color(0xFFA8957A),
                    ),
                  ),
                ),
                if (c.isEmpty)
                  const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.draw_outlined, size: 16, color: Color(0xFFB4A389)),
                        SizedBox(width: 8),
                        Text(
                          'Draw your signature here',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB4A389),
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned.fill(
                  // The pad sits in a scrolling page, and an ordinary pan
                  // loses a downward stroke to the scroll. This one claims
                  // the finger the moment it lands on the paper.
                  child: RawGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    gestures: {
                      _EagerPan: GestureRecognizerFactoryWithHandlers<_EagerPan>(
                        _EagerPan.new,
                        (r) => r
                          ..onStart = (d) {
                            HapticFeedback.selectionClick();
                            c._start(d.localPosition);
                          }
                          ..onUpdate = (d) => c._extend(d.localPosition),
                      ),
                    },
                    child: CustomPaint(painter: _InkPainter(c._strokes, c._strokes.length)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: c.isEmpty ? null : c.undo,
              icon: const Icon(Icons.undo_rounded, size: 16),
              label: const Text('Undo'),
            ),
            TextButton.icon(
              onPressed: c.isEmpty ? null : c.clear,
              icon: const Icon(Icons.layers_clear_outlined, size: 16),
              label: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }
}

/// A pan that wins the gesture arena outright, so a stroke is never taken
/// for a scroll.
class _EagerPan extends PanGestureRecognizer {
  _EagerPan() : super(debugOwner: null);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.strokes, this.count);

  final List<List<Offset>> strokes;

  /// Changes whenever a stroke starts, so a repaint is not skipped.
  final int count;

  @override
  void paint(Canvas canvas, Size size) => _paintStrokes(canvas, strokes);

  // The strokes list is mutated in place as the finger moves, so every frame
  // is a new drawing.
  @override
  bool shouldRepaint(covariant _InkPainter old) => true;
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final dashes = (box.maxWidth / 8).floor();
      return Row(
        children: [
          for (var i = 0; i < dashes; i++)
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                color: const Color(0xFFC9B89C),
              ),
            ),
        ],
      );
    },
  );
}
