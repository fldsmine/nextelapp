import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/features/dashboard/domain/dashboard_bridge_message.dart';

void main() {
  test('parses only the documented no-argument bridge methods', () {
    final message = DashboardBridgeMessage.parse(['showProfile']);

    expect(message?.method, DashboardBridgeMethod.showProfile);
    expect(message?.payload, isNull);
  });

  test('requires exactly one image payload for canvas actions', () {
    final image = DashboardBridgeMessage.parse([
      'handleCanvasImage',
      'data:image/png;base64,AAAA',
    ]);
    final share = DashboardBridgeMessage.parse([
      'handleCanvasShare',
      'AAAA',
    ]);

    expect(image?.method, DashboardBridgeMethod.handleCanvasImage);
    expect(image?.payload, 'data:image/png;base64,AAAA');
    expect(share?.method, DashboardBridgeMethod.handleCanvasShare);
    expect(share?.payload, 'AAAA');
    expect(DashboardBridgeMessage.parse(['handleCanvasImage']), isNull);
    expect(
      DashboardBridgeMessage.parse(['handleCanvasShare', 'AAAA', 'extra']),
      isNull,
    );
  });

  test('rejects unknown methods, non-string methods, and extra arguments', () {
    expect(DashboardBridgeMessage.parse([]), isNull);
    expect(DashboardBridgeMessage.parse([3]), isNull);
    expect(DashboardBridgeMessage.parse(['unlistedMethod']), isNull);
    expect(DashboardBridgeMessage.parse(['logout', 'extra']), isNull);
  });
}
