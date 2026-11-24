import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_gym_flutter/core/theme/glass_theme.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';

void main() {
  test('glass palette uses the showcase indigo and ice accents', () {
    final darkGlass = GlassTheme.buildTheme(
      brightness: Brightness.dark,
      glassEnabled: true,
    );
    final lightGlass = GlassTheme.buildTheme(
      brightness: Brightness.light,
      glassEnabled: true,
    );
    final darkFlat = GlassTheme.buildTheme(
      brightness: Brightness.dark,
      glassEnabled: false,
    );

    expect(darkGlass.colorScheme.primary, const Color(0xFFB7A6FF));
    expect(darkGlass.colorScheme.secondary, const Color(0xFF82D7FF));
    expect(lightGlass.colorScheme.primary, const Color(0xFF5A49C8));
    expect(darkFlat.colorScheme.primary, GlassTheme.limeAccent);
    expect(darkGlass.progressIndicatorTheme.linearMinHeight, 12);
    expect(darkFlat.progressIndicatorTheme.linearMinHeight, 4);
  });

  testWidgets(
    'gel glass panel, dotted backdrop, and progress semantics render',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: GlassTheme.buildTheme(
            brightness: Brightness.dark,
            glassEnabled: true,
          ),
          home: Scaffold(
            body: GlassScaffoldBackground(
              glassEnabled: true,
              child: const Center(
                child: GlassPanel(
                  glassEnabled: true,
                  child: GlassProgressBar(
                    value: 0.7,
                    label: 'Workout progress',
                    glassEnabled: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(GlassScaffoldBackground), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(GlassProgressBar), findsOneWidget);
      expect(find.bySemanticsLabel('Workout progress'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('flat progress fallback remains a Material progress indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: GlassProgressBar(
              value: 0.4,
              label: 'Progress',
              glassEnabled: false,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
