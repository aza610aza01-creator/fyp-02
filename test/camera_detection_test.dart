import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_gym_flutter/models/camera_debug_report.dart';
import 'package:ai_gym_flutter/models/camera_detection.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';
import 'package:ai_gym_flutter/services/camera_file_deleter.dart';
import 'package:ai_gym_flutter/services/camera_detection_service.dart';
import 'package:ai_gym_flutter/services/diagnostics_service.dart';
import 'package:ai_gym_flutter/widgets/yolo_video_import_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CameraDetectionService createCameraService() {
    final diagnostics = DiagnosticsService();
    final service = CameraDetectionService(diagnostics: diagnostics);
    addTearDown(service.dispose);
    addTearDown(diagnostics.dispose);
    return service;
  }

  test('camera detector starts idle without fabricated camera results', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final service = createCameraService();

    expect(service.isCameraReady, isFalse);
    expect(service.isLiveStreaming, isFalse);
    expect(service.detections, isEmpty);
    expect(service.engineMode, DetectionEngineMode.yoloV8PosePosture);
    expect(
      service.availableTrainedYoloModels,
      contains('Ultralytics YOLO26n-Pose (Android)'),
    );
    expect(service.currentPosture.keypoints, isEmpty);

    service.runYoloBenchmarkSample(userId: 'guest-local-user', isZh: false);
    expect(service.detections, isEmpty);
    expect(service.liveShowcaseFeed, isEmpty);

    service.setEngineMode(
      DetectionEngineMode.mlKitObject,
      userId: 'guest-local-user',
      isZh: false,
    );
    expect(service.engineMode, DetectionEngineMode.yoloV8PosePosture);
    expect(service.errorMessage, contains('Android camera uses'));
  });

  test('camera debug report lists setup, preview, and inference stages', () {
    final service = createCameraService();
    final report = service.cameraDebugReport;

    expect(
      report.checks.map((check) => check.stage),
      CameraFailureStage.values,
    );
    expect(report.hasFailure, isFalse);
    expect(
      report.checks
          .where((check) => check.stage == CameraFailureStage.inference)
          .single
          .status,
      CameraCheckStatus.pending,
    );
  });

  test('Windows camera detector selects the Python YOLO bridge', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final service = createCameraService();

    expect(service.supportsPythonYolo, isTrue);
    expect(service.engineMode, DetectionEngineMode.yoloV8PosePosture);
    expect(service.isCameraReady, isFalse);
  });

  test('Windows push-up camera view can switch between front and side', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final service = createCameraService();

    expect(service.pythonPushupViewMode, 'side');
    service.setPythonPushupViewMode('front');
    expect(service.pythonPushupViewMode, 'front');
    expect(
      () => service.setPythonPushupViewMode('overhead'),
      throwsArgumentError,
    );
  });

  test(
    'video YOLO analysis is limited to the supported Windows runtime',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final service = createCameraService();

      await expectLater(
        service.analyzeVideo(
          videoPath: 'exercise.mp4',
          videoName: 'exercise.mp4',
          userId: 'guest-local-user',
          isZh: false,
        ),
        throwsUnsupportedError,
      );
    },
  );

  testWidgets('YOLO video import action is Windows-only', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final service = createCameraService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: YoloVideoImportButton(
            cameraService: service,
            userId: 'guest-local-user',
            isZh: false,
          ),
        ),
      ),
    );
    expect(
      find.byKey(const Key('import_video_for_yolo_button')),
      findsOneWidget,
    );

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: YoloVideoImportButton(
            cameraService: service,
            userId: 'guest-local-user',
            isZh: false,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('import_video_for_yolo_button')), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  test('unavailable pose evaluation contains no generated keypoints', () {
    final posture = PostureEvaluation.unavailable(PostureExerciseTarget.pushUp);

    expect(posture.keypoints, isEmpty);
    expect(posture.formScore, 0);
    expect(posture.headlineEn, 'Pose model unavailable');
  });

  testWidgets('skeleton overlay displays localized pose correctness', (
    tester,
  ) async {
    const posture = PostureEvaluation(
      exercise: PostureExerciseTarget.squat,
      status: PostureStatus.correct,
      formScore: 92,
      primaryJointLabel: 'Knee',
      primaryAngleDeg: 90,
      secondaryJointLabel: 'Hip',
      secondaryAngleDeg: 110,
      symmetryPercent: 95,
      goodReps: 3,
      formAlerts: 0,
      headlineEn: 'Squat form matched',
      headlineZh: '深蹲姿勢符合',
      tipEn: 'Keep your torso braced.',
      tipZh: '保持核心穩定。',
      keypoints: <PostureKeypoint>[
        PostureKeypoint(index: 0, name: 'nose', x: 0.5, y: 0.2),
      ],
      modelName: 'Test pose model',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 320,
            child: DetectionBoundingBoxOverlay(
              detections: <CameraDetectionRecord>[],
              postureEvaluation: posture,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Form correct • 92%'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 320,
            child: DetectionBoundingBoxOverlay(
              detections: <CameraDetectionRecord>[],
              postureEvaluation: posture,
              isZh: true,
            ),
          ),
        ),
      ),
    );
    expect(find.text('姿勢正確 • 92%'), findsOneWidget);
  });

  test('Android pose angle computation uses real keypoint coordinates', () {
    expect(
      CameraDetectionService.computeJointAngleDegrees(
        const Offset(0, 1),
        Offset.zero,
        const Offset(1, 0),
      ),
      closeTo(90, 0.001),
    );
  });

  test('Android YOLO streaming detections decode boxes and pose keypoints', () {
    final detections = CameraDetectionService.parseAndroidYoloStreamDetections(
      <Object>[
        <String, Object>{
          'classIndex': 0,
          'className': 'person',
          'confidence': 0.91,
          'boundingBox': <String, double>{
            'left': 10,
            'top': 20,
            'right': 90,
            'bottom': 180,
          },
          'normalizedBox': <String, double>{
            'left': 0.1,
            'top': 0.1,
            'right': 0.9,
            'bottom': 0.9,
          },
          'keypoints': List<double>.generate(
            17 * 3,
            (index) => index % 3 == 2 ? 0.95 : index.toDouble(),
          ),
        },
      ],
    );

    expect(detections, hasLength(1));
    expect(detections.single.className, 'person');
    expect(detections.single.confidence, 0.91);
    expect(detections.single.keypoints, hasLength(17));
    expect(detections.single.keypointConfidences, everyElement(0.95));
    expect(
      CameraDetectionService.parseAndroidYoloStreamDetections(null),
      isEmpty,
    );
  });

  test('camera snapshot cleanup removes the captured file', () async {
    final directory = await Directory.systemTemp.createTemp('ai-gym-camera-');
    addTearDown(() => directory.delete(recursive: true));
    final snapshot = File(
      '${directory.path}${Platform.pathSeparator}capture.jpg',
    );
    await snapshot.writeAsBytes(<int>[1, 2, 3]);

    await deleteCameraFile(snapshot.path);

    expect(await snapshot.exists(), isFalse);
  });
}
