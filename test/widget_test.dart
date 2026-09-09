import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sori_example_flutter/main.dart';
import 'package:sorisdk_flutter/sorisdk_flutter_platform_interface.dart';

void main() {
  test('stringKeyedMap converts platform payload keys to strings', () {
    final result = stringKeyedMap(<Object, Object?>{
      'name': 'Summer Campaign',
      42: 'marker',
    });

    expect(result, <String, Object?>{
      'name': 'Summer Campaign',
      '42': 'marker',
    });
  });

  testWidgets('current marker events update and clear the displayed name', (
    tester,
  ) async {
    final previousPlatform = SorisdkFlutterPlatform.instance;
    final platform = _EventPlatform();
    SorisdkFlutterPlatform.instance = platform;

    try {
      await tester.pumpWidget(const SoriExampleApp());

      for (final name in ['Alpha', 'Beta']) {
        platform.controller.add(
          SORIRecognitionEvent(
            type: SORIRecognitionEventType.audioMarkerFound,
            audioMarkerIdentity: SORIAudioMarkerIdentity(
              id: 'marker-id',
              name: name,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Marker $name'), findsOneWidget);
      }
      expect(find.text('Marker Alpha'), findsNothing);
      expect(find.text('Marker marker-id'), findsNothing);

      platform.controller.add(
        const SORIRecognitionEvent(type: SORIRecognitionEventType.ready),
      );
      await tester.pumpAndSettle();
      expect(find.text('Marker Beta'), findsOneWidget);

      platform.controller.add(
        const SORIRecognitionEvent(
          type: SORIRecognitionEventType.audioMarkerFound,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Marker Beta'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      SorisdkFlutterPlatform.instance = previousPlatform;
      await platform.controller.close();
    }
  });
}

class _EventPlatform extends SorisdkFlutterPlatform {
  final controller = StreamController<SORIRecognitionEvent>.broadcast();

  @override
  Stream<SORIRecognitionEvent> get events => controller.stream;
}
