import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_gym_flutter/widgets/camera_preview_layout.dart';

void main() {
  test('camera content width scales from phones through large displays', () {
    const viewports = <({double width, double expectedMaxWidth})>[
      (width: 360, expectedMaxWidth: 360),
      (width: 430, expectedMaxWidth: 430),
      (width: 800, expectedMaxWidth: 800),
      (width: 1024, expectedMaxWidth: 1024),
      (width: 1440, expectedMaxWidth: 1440),
      (width: 1920, expectedMaxWidth: 1600),
      (width: 2560, expectedMaxWidth: 1600),
    ];

    for (final viewport in viewports) {
      expect(
        cameraContentMaxWidthForViewport(viewport.width),
        viewport.expectedMaxWidth,
      );
      expect(
        cameraContentHorizontalPaddingForViewport(viewport.width),
        greaterThanOrEqualTo(12),
      );
      expect(
        cameraContentHorizontalPaddingForViewport(viewport.width),
        lessThanOrEqualTo(24),
      );
    }
  });

  test('requested screen sizes get bounded responsive camera previews', () {
    const devices = <({String name, Size viewport})>[
      (name: '6.1-inch phone', viewport: Size(390, 844)),
      (name: '6.3-inch phone', viewport: Size(402, 874)),
      (name: '6.67-inch phone', viewport: Size(420, 912)),
      (name: '6.9-inch phone', viewport: Size(430, 932)),
      (name: '10.1-inch tablet', viewport: Size(800, 1280)),
      (name: '11-inch tablet', viewport: Size(834, 1194)),
      (name: '12.1-inch tablet', viewport: Size(900, 1440)),
      (name: '14-inch laptop', viewport: Size(1366, 768)),
      (name: '16-inch laptop', viewport: Size(1440, 900)),
      (name: '24-inch monitor', viewport: Size(1920, 1080)),
      (name: '27-inch monitor', viewport: Size(2560, 1440)),
    ];

    for (final device in devices) {
      final height = cameraPreviewHeightForViewport(
        viewportSize: device.viewport,
        safeAreaInsets: const EdgeInsets.only(top: 24, bottom: 24),
        preferredHeightFactor: 0.48,
      );

      expect(
        height,
        greaterThan(0),
        reason: '${device.name} should have a visible preview',
      );
      expect(
        height,
        lessThanOrEqualTo(device.viewport.height - 48),
        reason: '${device.name} preview must respect safe areas',
      );
      expect(
        cameraContentMaxWidthForViewport(device.viewport.width),
        lessThanOrEqualTo(device.viewport.width),
        reason: '${device.name} content must not exceed its viewport width',
      );
    }
  });

  test('camera preview stays within common phone viewport sizes', () {
    const viewports = <Size>[
      Size(360, 800),
      Size(393, 873),
      Size(412, 915),
      Size(430, 932),
    ];

    for (final viewport in viewports) {
      final height = cameraPreviewHeightForViewport(
        viewportSize: viewport,
        safeAreaInsets: const EdgeInsets.only(top: 24, bottom: 24),
        preferredHeightFactor: 0.48,
      );

      expect(height, greaterThanOrEqualTo(180));
      expect(height, lessThanOrEqualTo(viewport.height - 48));
      expect(height, lessThanOrEqualTo(viewport.height * 0.36 + 0.001));
    }
  });

  test(
    'camera preview scales across tablet, laptop, and desktop viewports',
    () {
      const viewports = <Size>[
        Size(800, 1280),
        Size(834, 1194),
        Size(1024, 1366),
        Size(1366, 768),
        Size(1440, 900),
        Size(1920, 1080),
        Size(2560, 1440),
      ];
      const safeAreaInsets = EdgeInsets.only(top: 24, bottom: 24);

      for (final viewport in viewports) {
        final height = cameraPreviewHeightForViewport(
          viewportSize: viewport,
          safeAreaInsets: safeAreaInsets,
          preferredHeightFactor: 0.48,
        );

        expect(height, greaterThanOrEqualTo(0));
        expect(height, lessThanOrEqualTo(720));
        expect(height, lessThanOrEqualTo(viewport.height - 48));
      }
    },
  );

  test('camera preview remains usable on short viewports with insets', () {
    final height = cameraPreviewHeightForViewport(
      viewportSize: const Size(320, 568),
      safeAreaInsets: const EdgeInsets.only(top: 24, bottom: 24),
      preferredHeightFactor: 0.85,
    );

    expect(height, closeTo(187.2, 0.001));
  });

  test('camera preview respects very short landscape safe areas', () {
    final height = cameraPreviewHeightForViewport(
      viewportSize: const Size(800, 400),
      safeAreaInsets: const EdgeInsets.only(top: 24, bottom: 24),
      preferredHeightFactor: 0.48,
    );

    expect(height, lessThanOrEqualTo(352 * 0.42));
  });
}
