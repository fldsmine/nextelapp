enum DashboardBridgeMethod {
  showMenu,
  showProfile,
  openAppSettings,
  openSupportTickets,
  openCouponSearch,
  logout,
  handleCanvasImage,
  handleCanvasShare,
}

class DashboardBridgeMessage {
  const DashboardBridgeMessage({required this.method, this.payload});

  final DashboardBridgeMethod method;
  final Object? payload;

  static DashboardBridgeMessage? parse(List<Object?> arguments) {
    if (arguments.isEmpty || arguments.first is! String) return null;
    final name = arguments.first as String;
    final method = switch (name) {
      'showMenu' => DashboardBridgeMethod.showMenu,
      'showProfile' => DashboardBridgeMethod.showProfile,
      'openAppSettings' => DashboardBridgeMethod.openAppSettings,
      'openSupportTickets' => DashboardBridgeMethod.openSupportTickets,
      'openCouponSearch' => DashboardBridgeMethod.openCouponSearch,
      'logout' => DashboardBridgeMethod.logout,
      'handleCanvasImage' => DashboardBridgeMethod.handleCanvasImage,
      'handleCanvasShare' => DashboardBridgeMethod.handleCanvasShare,
      _ => null,
    };
    if (method == null) return null;

    final expectsPayload = method == DashboardBridgeMethod.handleCanvasImage ||
        method == DashboardBridgeMethod.handleCanvasShare;
    if (arguments.length != (expectsPayload ? 2 : 1)) return null;
    return DashboardBridgeMessage(
      method: method,
      payload: expectsPayload ? arguments[1] : null,
    );
  }
}
