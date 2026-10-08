import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/core/security/native_platform_bridge.dart';

const _channel = MethodChannel('pynith.apps.nextel/native');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
  });

  test('checks availability of strong biometrics on Android', () async {
    MethodCall? receivedCall;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      receivedCall = call;
      return true;
    });
    final bridge = NativePlatformBridge(channel: _channel);

    expect(await bridge.canAuthenticateWithStrongBiometrics(), isTrue);
    expect(receivedCall?.method, 'canAuthenticateWithStrongBiometrics');
  });

  test('requests a strong-only native biometric prompt', () async {
    MethodCall? receivedCall;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      receivedCall = call;
      return true;
    });
    final bridge = NativePlatformBridge(channel: _channel);

    expect(
      await bridge.authenticateWithStrongBiometrics(
        title: 'Biometric sign-in',
        subtitle: 'Confirm your identity',
      ),
      isTrue,
    );
    expect(receivedCall?.method, 'authenticateWithStrongBiometrics');
    expect(receivedCall?.arguments, {
      'title': 'Biometric sign-in',
      'subtitle': 'Confirm your identity',
      'negativeButtonText': 'Cancel',
    });
  });

  test('forwards text to the native app-sharing chooser', () async {
    MethodCall? receivedCall;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      receivedCall = call;
      return true;
    });
    final bridge = NativePlatformBridge(channel: _channel);

    expect(
      await bridge.shareText(
        subject: 'Check out this app',
        text: 'Try Nextel at https://example.test',
      ),
      isTrue,
    );
    expect(receivedCall?.method, 'shareText');
    expect(receivedCall?.arguments, {
      'subject': 'Check out this app',
      'text': 'Try Nextel at https://example.test',
    });
  });

  test('opens the app listing through the native Play Store bridge', () async {
    MethodCall? receivedCall;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      receivedCall = call;
      return true;
    });
    final bridge = NativePlatformBridge(channel: _channel);

    expect(await bridge.openPlayStoreListing(), isTrue);
    expect(receivedCall?.method, 'openPlayStoreListing');
  });

  test('queues logout tokens for native background revocation', () async {
    MethodCall? receivedCall;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      receivedCall = call;
      return true;
    });
    final bridge = NativePlatformBridge(channel: _channel);

    expect(await bridge.queueLogoutRevocation('session-token'), isTrue);
    expect(receivedCall?.method, 'queueLogoutRevocation');
    expect(receivedCall?.arguments, {'token': 'session-token'});
  });

  test('removes revoked tokens from the native retry queue', () async {
    MethodCall? receivedCall;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      receivedCall = call;
      return true;
    });
    final bridge = NativePlatformBridge(channel: _channel);

    expect(await bridge.removeQueuedLogoutRevocation('session-token'), isTrue);
    expect(receivedCall?.method, 'removeQueuedLogoutRevocation');
    expect(receivedCall?.arguments, {'token': 'session-token'});
  });

  test('does not send empty logout tokens over the channel', () async {
    var called = false;
    messenger.setMockMethodCallHandler(_channel, (_) async {
      called = true;
      return true;
    });
    final bridge = NativePlatformBridge(channel: _channel);

    expect(await bridge.queueLogoutRevocation(' '), isFalse);
    expect(await bridge.removeQueuedLogoutRevocation(''), isFalse);
    expect(called, isFalse);
  });
}
