import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:window_manager/window_manager.dart';

void main() {
  const MethodChannel channel = MethodChannel('window_manager');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      null,
    );
  });
}
