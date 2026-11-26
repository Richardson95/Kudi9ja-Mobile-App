import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../signup_draft.dart';
import 'step_scaffold.dart';

/// Face check: blink, turn your head, open your mouth.
///
/// The movements are read on the phone with ML Kit face detection. One photo
/// of each movement is kept in the draft and sent to the server, which keeps
/// them on the customer's record for the team to see. Continue stays disabled
/// until all three have been done. Not identity verification.
class FaceCheckStep extends StatefulWidget {
  const FaceCheckStep({
    super.key,
    required this.draft,
    required this.onNext,
    this.busy = false,
  });

  final SignupDraft draft;
  final VoidCallback onNext;
  final bool busy;

  @override
  State<FaceCheckStep> createState() => _FaceCheckStepState();
}

enum _Pose { blink, turn, mouth }

enum _Phase { intro, starting, running, passed, failed }

const _prompts = {
  _Pose.blink: 'Blink your eyes',
  _Pose.turn: 'Slowly turn your head to one side',
  _Pose.mouth: 'Open your mouth wide',
};

/// Frames a turn or open mouth must be held for, so a flicker is not counted.
/// A blink needs only one frame: it lasts a tenth of a second, and a cheap
/// phone may see only one frame of it.
const _holdFrames = 2;

/// After this long on one movement with a face in view, the customer may take the photo themselves.
const _manualAfter = Duration(seconds: 20);

class _FaceCheckStepState extends State<FaceCheckStep> {
  CameraController? _camera;
  FaceDetector? _detector;
  _Phase _phase = _Phase.intro;
  int _step = 0;
  String? _hint;
  String? _error;
  final Map<_Pose, String> _photos = {};

  bool _processing = false;
  bool _capturing = false;
  int _held = 0;
  double _openBaseline = 0;
  bool _centred = false;
  DateTime _stepStarted = DateTime.now();
  bool _faceInView = false;
  bool _canTakeManually = false;

  bool get _passed => _phase == _Phase.passed;

  @override
  void initState() {
    super.initState();
    if (widget.draft.faceBlink.isNotEmpty &&
        widget.draft.faceTurn.isNotEmpty &&
        widget.draft.faceMouth.isNotEmpty) {
      _phase = _Phase.passed;
      _photos[_Pose.blink] = widget.draft.faceBlink;
      _photos[_Pose.turn] = widget.draft.faceTurn;
      _photos[_Pose.mouth] = widget.draft.faceMouth;
    }
  }

  @override
  void dispose() {
    unawaited(_stopCamera());
    unawaited(_detector?.close());
    super.dispose();
  }

  Future<void> _stopCamera() async {
    final camera = _camera;
    _camera = null;
    if (camera == null) return;
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
    } catch (_) {}
    await camera.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _phase = _Phase.starting;
      _error = null;
      _hint = null;
      _step = 0;
      _photos.clear();
      _held = 0;
      _openBaseline = 0;
      _centred = false;
      _faceInView = false;
      _canTakeManually = false;
    });
    widget.draft
      ..faceBlink = ''
      ..faceTurn = ''
      ..faceMouth = '';
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await camera.initialize();
      _detector ??= FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableContours: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
      if (!mounted) {
        await camera.dispose();
        return;
      }
      _camera = camera;
      _stepStarted = DateTime.now();
      setState(() => _phase = _Phase.running);
      await camera.startImageStream(_onFrame);
    } on CameraException catch (e) {
      _fail(e.code == 'CameraAccessDenied' || e.code == 'CameraAccessDeniedWithoutPrompt'
          ? 'Kudi9ja needs your camera for the face check. Allow camera access in your phone settings, then try again.'
          : 'We could not open your camera. Try again.');
    } catch (_) {
      _fail('The face check could not start. Try again.');
    }
  }

  void _fail(String message) {
    unawaited(_stopCamera());
    if (!mounted) return;
    setState(() {
      _phase = _Phase.failed;
      _error = message;
    });
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_processing || _capturing || _phase != _Phase.running) return;
    final camera = _camera;
    final detector = _detector;
    if (camera == null || detector == null) return;
    final input = _toInputImage(image, camera.description);
    if (input == null) return;

    _processing = true;
    try {
      final faces = await detector.processImage(input);
      if (!mounted || _phase != _Phase.running) return;
      _faceInView = faces.length == 1;
      if (faces.isEmpty) {
        _setHint('We cannot see your face. Face the camera in good light.');
        _held = 0;
        return;
      }
      if (faces.length > 1) {
        _setHint('Only you should be in the picture.');
        _held = 0;
        return;
      }
      _setHint(null);
      if (!_canTakeManually && DateTime.now().difference(_stepStarted) > _manualAfter) {
        setState(() => _canTakeManually = true);
      }
      final face = faces.first;
      final pose = _Pose.values[_step];
      var done = false;
      switch (pose) {
        case _Pose.blink:
          final left = face.leftEyeOpenProbability;
          final right = face.rightEyeOpenProbability;
          if (left == null || right == null) break;
          // Measured against this person's own open eyes, so small eyes,
          // glasses or a bright window behind them do not stop a real blink.
          final open = (left + right) / 2;
          _openBaseline = math.max(_openBaseline, open);
          done = _openBaseline > 0 && (open < 0.4 || open < _openBaseline * 0.5);
        case _Pose.turn:
          final yaw = face.headEulerAngleY ?? 0;
          if (yaw.abs() < 12) _centred = true;
          _held = _centred && yaw.abs() > 20 ? _held + 1 : 0;
          done = _held >= _holdFrames;
        case _Pose.mouth:
          _held = _mouthOpen(face) ? _held + 1 : 0;
          done = _held >= _holdFrames;
      }
      if (done) {
        _held = 0;
        await _capture(pose);
      }
    } catch (_) {
      // A dropped frame; the next one is along in a moment.
    } finally {
      _processing = false;
    }
  }

  /// Gap between the lips, as a share of the face's height.
  bool _mouthOpen(Face face) {
    final upper = face.contours[FaceContourType.upperLipBottom]?.points;
    final lower = face.contours[FaceContourType.lowerLipTop]?.points;
    if (upper == null || lower == null || upper.isEmpty || lower.isEmpty) return false;
    double mid(List<math.Point<int>> pts) => pts.map((p) => p.y).reduce((a, b) => a + b) / pts.length;
    final gap = (mid(lower) - mid(upper)).abs();
    return gap / face.boundingBox.height > 0.06;
  }

  Future<void> _capture(_Pose pose) async {
    final camera = _camera;
    if (camera == null) return;
    _capturing = true;
    try {
      await camera.stopImageStream();
      final file = await camera.takePicture();
      final bytes = await file.readAsBytes();
      unawaited(File(file.path).delete().catchError((_) => File(file.path)));
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _photos[pose] = dataUrl;
        _step++;
        _canTakeManually = false;
      });
      _stepStarted = DateTime.now();
      if (_step >= _Pose.values.length) {
        widget.draft
          ..faceBlink = _photos[_Pose.blink]!
          ..faceTurn = _photos[_Pose.turn]!
          ..faceMouth = _photos[_Pose.mouth]!;
        await _stopCamera();
        if (mounted) setState(() => _phase = _Phase.passed);
        return;
      }
      await camera.startImageStream(_onFrame);
    } catch (_) {
      _fail('The photo could not be taken. Try again.');
    } finally {
      _capturing = false;
    }
  }

  /// The fallback after [_manualAfter]: keeps the current frame for this movement.
  Future<void> _takeManually() async {
    if (_capturing || !_faceInView || _phase != _Phase.running) return;
    while (_processing) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (_capturing || _phase != _Phase.running) return;
    _held = 0;
    await _capture(_Pose.values[_step]);
  }

  void _setHint(String? hint) {
    if (hint != _hint && mounted) setState(() => _hint = hint);
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null || image.planes.isEmpty) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final live = _phase == _Phase.starting || _phase == _Phase.running;
    return StepScaffold(
      headline: 'Face check',
      subhead:
          'Look at the camera, then blink, turn your head and open your mouth when asked. It takes a few seconds, and three photos are saved to your account.',
      actionLabel: 'Continue',
      loading: widget.busy,
      onAction: _passed && !widget.busy ? widget.onNext : null,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              color: AppColors.surface,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (live && camera != null && camera.value.isInitialized)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: camera.value.previewSize?.height ?? 480,
                        height: camera.value.previewSize?.width ?? 640,
                        child: CameraPreview(camera),
                      ),
                    )
                  else
                    Center(
                      child: _passed
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 64, color: AppColors.success),
                                const SizedBox(height: AppSpacing.sm),
                                Text('Face check passed', style: Theme.of(context).textTheme.titleLarge),
                              ],
                            )
                          : _phase == _Phase.starting
                              ? const CircularProgressIndicator()
                              : Icon(Icons.face_retouching_natural, size: 80, color: AppColors.textTertiary),
                    ),
                  if (_phase == _Phase.running)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.65),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            Text(
                              'STEP ${_step + 1} OF 3',
                              style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.6),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _prompts[_Pose.values[math.min(_step, 2)]]!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                            ),
                            if (_hint != null) ...[
                              const SizedBox(height: 4),
                              Text(_hint!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.danger, fontSize: 13)),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final pose in _Pose.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          width: 2,
                          color: _photos[pose] != null ? AppColors.success : AppColors.stroke,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _photos[pose] != null
                          ? Image.memory(
                              base64Decode(_photos[pose]!.split(',').last),
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pose == _Pose.blink ? 'Blink' : pose == _Pose.turn ? 'Turn' : 'Mouth',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (_phase == _Phase.running && _canTakeManually)
          OutlinedButton.icon(
            onPressed: _takeManually,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Take the photo'),
          ),
        if (_phase == _Phase.intro || _phase == _Phase.failed || _passed)
          OutlinedButton.icon(
            onPressed: _start,
            icon: Icon(_phase == _Phase.intro ? Icons.photo_camera_outlined : Icons.refresh),
            label: Text(_phase == _Phase.intro ? 'Start face check' : _passed ? 'Do it again' : 'Try again'),
          ),
        if (_error != null)
          Text(_error!, style: TextStyle(color: AppColors.danger, height: 1.4)),
      ],
    );
  }
}
