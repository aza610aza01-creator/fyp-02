import 'package:flutter_test/flutter_test.dart';
import 'package:ai_gym_flutter/models/exercise.dart';

void main() {
  test('default exercise catalog has working sample video URLs', () {
    final exercises = Exercise.defaultSeedExercises();
    final demoUrls = exercises
        .where((exercise) => exercise.demoUrl != null)
        .map((exercise) => exercise.demoUrl!)
        .toList();

    expect(demoUrls, hasLength(6));
    expect(
      demoUrls.every((url) => Uri.tryParse(url)?.host == 'www.youtube.com'),
      isTrue,
    );
  });
}
