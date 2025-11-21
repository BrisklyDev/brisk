import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(640, 480),
      title: 'window_manager_test',
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  testWidgets('getBounds', (tester) async {
    expect(
      await windowManager.getBounds(),
      isA<Rect>().having((r) => r.size, 'size', const Size(640, 480)),
    );
  });

  testWidgets(
    'isAlwaysOnBottom',
    (tester) async {
      expect(await windowManager.isAlwaysOnBottom(), isFalse);
    },
    skip: Platform.isMacOS || Platform.isWindows,
  );

  testWidgets('isAlwaysOnTop', (tester) async {
    expect(await windowManager.isAlwaysOnTop(), isFalse);
  });

  testWidgets('isClosable', (tester) async {
    expect(await windowManager.isClosable(), isTrue);
  });

  testWidgets('isFocused', (tester) async {
    expect(await windowManager.isFocused(), isTrue);
  });

  testWidgets('isFullScreen', (tester) async {
    expect(await windowManager.isFullScreen(), isFalse);
  });

  testWidgets(
    'hasShadow',
    (tester) async {
      expect(await windowManager.hasShadow(), isTrue);
    },
    skip: Platform.isLinux,
  );

  testWidgets('isMaximizable', (tester) async {
    expect(await windowManager.isMaximizable(), isTrue);
  });

  testWidgets('isMaximized', (tester) async {
    expect(await windowManager.isMaximized(), isFalse);
  });

  testWidgets(
    'isMinimizable',
    (tester) async {
      expect(await windowManager.isMinimizable(), isTrue);
    },
    skip: Platform.isMacOS,
  );

  testWidgets('isMinimized', (tester) async {
    expect(await windowManager.isMinimized(), isFalse);
  });

  testWidgets(
    'isMovable',
    (tester) async {
      expect(await windowManager.isMovable(), isTrue);
    },
    skip: Platform.isLinux || Platform.isWindows,
  );

  testWidgets('getOpacity', (tester) async {
    expect(await windowManager.getOpacity(), 1.0);
  });

  testWidgets('getPosition', (tester) async {
    expect(await windowManager.getPosition(), isA<Offset>());
  });

  testWidgets('isPreventClose', (tester) async {
    expect(await windowManager.isPreventClose(), isFalse);
  });

  testWidgets('isResizable', (tester) async {
    expect(await windowManager.isResizable(), isTrue);
  });

  testWidgets('getSize', (tester) async {
    expect(await windowManager.getSize(), const Size(640, 480));
  });

  testWidgets(
    'isSkipTaskbar',
    (tester) async {
      expect(await windowManager.isSkipTaskbar(), isFalse);
    },
    skip: Platform.isWindows,
  );

  testWidgets('getTitle', (tester) async {
    expect(await windowManager.getTitle(), 'window_manager_test');
  });

  testWidgets('getTitleBarHeight', (tester) async {
    expect(await windowManager.getTitleBarHeight(), isNonNegative);
  });

  testWidgets('isVisible', (tester) async {
    expect(await windowManager.isVisible(), isTrue);
  });
}
