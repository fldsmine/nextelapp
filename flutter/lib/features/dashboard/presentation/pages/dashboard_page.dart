import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/providers.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/api_failure.dart';
import '../../../../core/security/native_platform_bridge.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../features/auth/presentation/pages/suspended_page.dart';
import '../../domain/canvas_image_payload.dart';
import '../../domain/dashboard_bridge_message.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({this.initialUri, super.key});

  /// Validated destination returned by POST /web-session, if already acquired.
  final Uri? initialUri;

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  static const _bridgeName = 'nextelDashboardBridge';

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  InAppWebViewController? _controller;
  Uri? _initialLoadUri;
  Uri? _lastTrustedUri;
  DateTime? _lastBackPress;
  bool _sessionReady = false;
  bool _loading = true;
  bool _drawerOpen = false;
  bool _handlingSessionRedirect = false;
  bool _logoutStarted = false;
  double _progress = 0;
  String? _pageError;

  AppConfig get _config => ref.read(appConfigProvider);
  NativePlatformBridge get _nativeBridge =>
      ref.read(nativePlatformBridgeProvider);
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_prepareSession());
  }

  Set<String> get _trustedOriginRules {
    final origin = _config.webOrigin.origin;
    if (defaultTargetPlatform == TargetPlatform.android) return {origin};
    return {'^${RegExp.escape(origin)}\$'};
  }

  Future<void> _prepareSession() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _pageError = null;
    });

    try {
      final token = await ref.read(sessionStoreProvider).readToken();
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        await _routeToLogin();
        return;
      }

      final requested = widget.initialUri;
      if (requested != null &&
          _config.isTrustedWebUri(requested) &&
          !_isNativeLoginPath(requested)) {
        _initialLoadUri = requested;
      } else {
        final webSession = await _authRepository.openWebSession();
        _initialLoadUri = webSession.destination;
      }

      if (!mounted) return;
      _lastTrustedUri = _initialLoadUri;
      setState(() {
        _sessionReady = true;
        _loading = true;
        _pageError = null;
      });
    } on ApiFailure catch (failure) {
      await _handleSessionFailure(failure);
    } catch (_) {
      if (mounted) {
        setState(() {
          _sessionReady = true;
          _loading = false;
          _pageError = 'Could not establish a secure website session. Please retry.';
        });
      }
    }
  }

  Future<void> _handleSessionFailure(ApiFailure failure) async {
    if (failure.statusCode == 401) {
      await _routeToLogin();
      return;
    }
    if (failure.statusCode == 403) {
      await _routeToSuspended(failure);
      return;
    }
    if (mounted) {
      setState(() {
        _sessionReady = true;
        _loading = false;
        _pageError = failure.displayMessage;
      });
    }
  }

  Future<void> _routeToSuspended(ApiFailure failure) async {
    final supportToken = failure.dataMap['support_token']?.toString();
    try {
      await _authRepository.handleSuspended(
        serverRevokedCurrentToken: supportToken?.isNotEmpty == true,
      );
    } catch (_) {
      // Navigation must still leave a suspended account out of the Dashboard.
    }
    if (!mounted) return;
    context.go(
      AppRoutes.suspended,
      extra: SuspendedRouteDetails(
        message: failure.message,
        supportToken: supportToken,
      ),
    );
  }

  bool _isNativeLoginPath(Uri uri) =>
      uri.path == '/login' || uri.path == '/auth/login';

  bool _isWebLogoutSignal(Uri uri) =>
      uri.path == '/mini-app' && uri.queryParameters['logged_out'] == '1';

  bool _isTrustedUrl(WebUri? webUri) {
    if (!mounted || webUri == null) return false;
    final uri = Uri.tryParse(webUri.toString());
    return uri != null && _config.isTrustedWebUri(uri);
  }

  Future<NavigationActionPolicy?> _handleNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    if (!mounted) return NavigationActionPolicy.CANCEL;
    final webUri = action.request.url;
    final uri = webUri == null ? null : Uri.tryParse(webUri.toString());
    if (uri == null) return NavigationActionPolicy.CANCEL;

    if (_config.isTrustedWebUri(uri)) {
      if (!action.isForMainFrame) return NavigationActionPolicy.ALLOW;
      if (_isWebLogoutSignal(uri)) {
        unawaited(_logout());
        return NavigationActionPolicy.CANCEL;
      }
      if (_isNativeLoginPath(uri)) {
        final token = await ref.read(sessionStoreProvider).readToken();
        if (!mounted) return NavigationActionPolicy.CANCEL;
        if (token == null || token.isEmpty) {
          await _routeToLogin();
        } else {
          unawaited(_refreshWebSession());
        }
        return NavigationActionPolicy.CANCEL;
      }

      _lastTrustedUri = uri;
      return NavigationActionPolicy.ALLOW;
    }

    // External top-level links keep their Android intent behavior. Frames may
    // not navigate or launch apps outside the trusted Nextel origin.
    if (!action.isForMainFrame) return NavigationActionPolicy.CANCEL;
    if (uri.userInfo.isNotEmpty) return NavigationActionPolicy.CANCEL;
    if (!const {'http', 'https', 'mailto', 'tel'}
        .contains(uri.scheme.toLowerCase())) {
      return NavigationActionPolicy.CANCEL;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No matching external activity is a safe no-op.
    }
    return NavigationActionPolicy.CANCEL;
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: _bridgeName,
      callback: _handleJavaScriptBridge,
    );
  }

  Future<Object?> _handleJavaScriptBridge(
    JavaScriptHandlerFunctionData data,
  ) async {
    if (!mounted) return null;
    final origin = Uri.tryParse(data.origin.toString());
    final frameUrl = Uri.tryParse(data.requestUrl.toString());
    if (!data.isMainFrame ||
        origin == null ||
        frameUrl == null ||
        !_config.isTrustedWebUri(origin) ||
        !_config.isTrustedWebUri(frameUrl)) {
      return null;
    }
    final message = DashboardBridgeMessage.parse(data.args);
    if (message == null) return null;

    switch (message.method) {
      case DashboardBridgeMethod.showMenu:
        _scaffoldKey.currentState?.openDrawer();
        break;
      case DashboardBridgeMethod.showProfile:
        await _loadTrustedPath('/dashboard/profile');
        break;
      case DashboardBridgeMethod.openAppSettings:
        if (mounted) await context.push(AppRoutes.settings);
        break;
      case DashboardBridgeMethod.openSupportTickets:
        await _openSupportTickets();
        break;
      case DashboardBridgeMethod.openCouponSearch:
        if (mounted) await context.push(AppRoutes.coupon);
        break;
      case DashboardBridgeMethod.logout:
        await _logout();
        break;
      case DashboardBridgeMethod.handleCanvasImage:
        await _saveCanvasImage(message.payload);
        break;
      case DashboardBridgeMethod.handleCanvasShare:
        await _shareCanvasImage(message.payload);
        break;
    }
    return null;
  }

  Future<ShowFileChooserResponse?> _showFileChooser(
    InAppWebViewController controller,
    ShowFileChooserRequest request,
  ) async {
    final currentUrl = await controller.getUrl();
    if (!_isTrustedUrl(currentUrl)) {
      return ShowFileChooserResponse(handledByClient: true);
    }

    try {
      final imageUri = await _nativeBridge.chooseWebViewImage();
      if (imageUri == null || imageUri.scheme != 'content') {
        return ShowFileChooserResponse(handledByClient: true);
      }
      return ShowFileChooserResponse(
        handledByClient: true,
        filePaths: [imageUri.toString()],
      );
    } catch (_) {
      if (mounted) _showMessage('Could not open the image picker.');
      return ShowFileChooserResponse(handledByClient: true);
    }
  }

  Future<void> _loadTrustedPath(String path) async {
    final uri = _config.webOrigin.replace(path: path);
    if (!_config.isTrustedWebUri(uri)) return;
    await _loadTrustedUri(uri);
  }

  Future<void> _loadTrustedUri(Uri uri) async {
    if (!_config.isTrustedWebUri(uri)) return;
    _lastTrustedUri = uri;
    if (mounted) {
      setState(() {
        _loading = true;
        _progress = 0;
        _pageError = null;
      });
    }
    await _controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri(uri.toString())),
    );
  }

  Future<void> _refreshWebSession() async {
    if (_handlingSessionRedirect || !mounted) return;
    _handlingSessionRedirect = true;
    setState(() {
      _loading = true;
      _pageError = null;
    });
    try {
      final result = await _authRepository.openWebSession();
      if (mounted) await _loadTrustedUri(result.destination);
    } on ApiFailure catch (failure) {
      await _handleSessionFailure(failure);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _pageError = 'Could not refresh the secure website session. Please retry.';
        });
      }
    } finally {
      _handlingSessionRedirect = false;
    }
  }

  void _onLoadStart(WebUri? url) {
    if (!_isTrustedUrl(url) || !mounted) return;
    _lastTrustedUri = Uri.tryParse(url.toString());
    setState(() {
      _loading = true;
      _progress = 0;
      _pageError = null;
    });
  }

  void _onLoadStop(WebUri? url) {
    if (!_isTrustedUrl(url) || !mounted) return;
    setState(() {
      _loading = false;
      _progress = 1;
      _pageError = null;
    });
  }

  void _onLoadError(WebResourceRequest request, WebResourceError error) {
    if (request.isForMainFrame != true || !mounted) return;
    setState(() {
      _loading = false;
      _pageError = 'Could not load the dashboard. Check your connection and retry.';
    });
  }

  void _onHttpError(
    WebResourceRequest request,
    WebResourceResponse response,
  ) {
    if (request.isForMainFrame != true || !mounted) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      unawaited(_refreshWebSession());
      return;
    }
    setState(() {
      _loading = false;
      _pageError = 'The dashboard returned an error. Please retry.';
    });
  }

  Future<void> _retry() async {
    if (!_sessionReady || _controller == null) {
      await _prepareSession();
      return;
    }
    final retryUri = _lastTrustedUri;
    if (retryUri == null || !_config.isTrustedWebUri(retryUri)) {
      await _refreshWebSession();
      return;
    }
    await _loadTrustedUri(retryUri);
  }

  Future<void> _openSupportTickets() async {
    final token = await ref.read(sessionStoreProvider).readToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      await _routeToLogin();
      return;
    }
    await context.push(AppRoutes.support, extra: token);
  }

  Future<void> _routeToLogin() async {
    try {
      await _authRepository.handleExpiredSession();
    } catch (_) {
      // Keep the user-facing flow available even if secure cleanup fails.
    } finally {
      if (mounted) context.go(AppRoutes.login);
    }
  }

  Future<void> _logout() async {
    if (_logoutStarted) return;
    _logoutStarted = true;
    try {
      await _authRepository.logout();
    } catch (_) {
      // Local token and WebView storage are cleared before best-effort revoke.
    } finally {
      if (mounted) context.go(AppRoutes.login);
    }
  }

  Future<void> _saveCanvasImage(Object? rawImage) async {
    try {
      final image = CanvasImagePayload.parse(rawImage);
      final saved = await _nativeBridge.saveCanvasImage(image.base64Data);
      if (mounted) {
        _showMessage(
          saved ? 'Image saved to Pictures/NovaPNL.' : 'Could not save the image.',
        );
      }
    } on FormatException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Could not save the image.');
    }
  }

  Future<void> _shareCanvasImage(Object? rawImage) async {
    try {
      final image = CanvasImagePayload.parse(rawImage);
      final shared = await _nativeBridge.shareCanvasImage(image.base64Data);
      if (mounted) {
        _showMessage(
          shared ? 'Choose an app to share the image.' : 'Could not share the image.',
        );
      }
    } on FormatException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Could not share the image.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onBack() async {
    if (_drawerOpen) {
      _scaffoldKey.currentState?.closeDrawer();
      return;
    }
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return;
    }

    final now = DateTime.now();
    final previous = _lastBackPress;
    if (previous == null || now.difference(previous) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      _showMessage('Please click BACK again to exit.');
      return;
    }
    await SystemNavigator.pop();
  }

  void _onPopInvoked(bool didPop) {
    if (!didPop) unawaited(_onBack());
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return Scaffold(body: _buildLoadingSurface());
    }

    final initialUri = _initialLoadUri ?? _config.dashboardUri;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: Scaffold(
        key: _scaffoldKey,
        onDrawerChanged: (open) => _drawerOpen = open,
        appBar: AppBar(
          title: const Text('Nextel'),
          actions: [
            IconButton(
              tooltip: 'Refresh dashboard',
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: _loading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress,
                  ),
                )
              : null,
        ),
        drawer: _buildDrawer(),
        body: Stack(
          children: [
            Positioned.fill(
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(initialUri.toString()),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  allowFileAccess: false,
                  allowContentAccess: false,
                  thirdPartyCookiesEnabled: false,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
                  supportMultipleWindows: false,
                  javaScriptCanOpenWindowsAutomatically: false,
                  safeBrowsingEnabled: true,
                  cacheEnabled: true,
                  useShouldOverrideUrlLoading: true,
                  useOnShowFileChooser: true,
                  javaScriptBridgeEnabled: true,
                  javaScriptBridgeForMainFrameOnly: true,
                  javaScriptBridgeOriginAllowList: _trustedOriginRules,
                  javaScriptHandlersForMainFrameOnly: true,
                  javaScriptHandlersOriginAllowList: _trustedOriginRules,
                  isInspectable: false,
                ),
                initialUserScripts: UnmodifiableListView<UserScript>([
                  UserScript(
                    source: _androidBridgeShim,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    forMainFrameOnly: true,
                    allowedOriginRules: _trustedOriginRules,
                  ),
                ]),
                onWebViewCreated: _onWebViewCreated,
                shouldOverrideUrlLoading: _handleNavigation,
                onShowFileChooser: _showFileChooser,
                onLoadStart: (controller, url) => _onLoadStart(url),
                onLoadStop: (controller, url) => _onLoadStop(url),
                onProgressChanged: (controller, progress) {
                  if (mounted) setState(() => _progress = progress / 100);
                },
                onReceivedError: (controller, request, error) =>
                    _onLoadError(request, error),
                onReceivedHttpError: (controller, request, response) =>
                    _onHttpError(request, response),
                onReceivedServerTrustAuthRequest: (controller, challenge) async =>
                    ServerTrustAuthResponse(
                  action: ServerTrustAuthResponseAction.CANCEL,
                ),
              ),
            ),
            if (_pageError != null)
              Positioned.fill(child: _buildErrorSurface(_pageError!))
            else if (_loading)
              Positioned.fill(child: _buildLoadingSurface()),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSurface() => ColoredBox(
        color: context.nextelColors.primary,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/branding/nextel_logo.png',
                    width: 210,
                    height: 78,
                    fit: BoxFit.contain,
                    semanticLabel: 'Nextel Connect',
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: context.nextelColors.accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Loading your dashboard…',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildErrorSurface(String message) => ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: context.nextelColors.muted,
                ),
                const SizedBox(height: 14),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildDrawer() => Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                color: context.nextelColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/branding/nextel_logo.png',
                      width: 158,
                      height: 58,
                      fit: BoxFit.contain,
                      semanticLabel: 'Nextel Connect',
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Next-Gen Memecoin App',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  children: [
                    _drawerItem(Icons.dashboard_outlined, 'Dashboard',
                        onTap: () => _loadTrustedPath('/dashboard')),
                    _drawerItem(Icons.bolt_outlined, 'Features / VAS',
                        onTap: () => _loadTrustedPath('/dashboard/vas')),
                    _drawerItem(Icons.person_outline, 'Profile',
                        onTap: () => _loadTrustedPath('/dashboard/profile')),
                    _drawerItem(Icons.support_agent_outlined, 'Support tickets',
                        onTap: _openSupportTickets),
                    _drawerItem(Icons.sports_esports_outlined, 'System games',
                        onTap: () => context.push(AppRoutes.games)),
                    _drawerItem(Icons.local_offer_outlined, 'Coupon search',
                        onTap: () => context.push(AppRoutes.coupon)),
                    _drawerItem(Icons.info_outline, 'About Nextel',
                        onTap: () => context.push(AppRoutes.about)),
                    _drawerItem(Icons.settings_outlined, 'App settings',
                        onTap: () => context.push(AppRoutes.settings)),
                    const Divider(height: 18),
                    _drawerItem(
                      Icons.logout,
                      'Log out',
                      onTap: _confirmLogout,
                      color: context.nextelColors.danger,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _drawerItem(
    IconData icon,
    String title, {
    required VoidCallback onTap,
    Color? color,
  }) =>
      ListTile(
        leading: Icon(icon, color: color ?? context.nextelColors.primary),
        title: Text(title, style: TextStyle(color: color)),
        onTap: () {
          _scaffoldKey.currentState?.closeDrawer();
          onTap();
        },
      );

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Log out'),
            content: const Text('Are you sure you want to log out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Log out'),
              ),
            ],
          ),
        ) ??
        false;
    if (shouldLogout && mounted) await _logout();
  }

  static const String _androidBridgeShim = r'''(function () {
  if (window.top !== window) return;
  var handler = 'nextelDashboardBridge';
  var queued = [];
  function send(method, args) {
    var bridge = window.flutter_inappwebview;
    if (bridge && typeof bridge.callHandler === 'function') {
      try {
        var result = bridge.callHandler.apply(bridge, [handler, method].concat(args));
        if (result && typeof result.catch === 'function') result.catch(function () {});
        return;
      } catch (_) {}
    }
    queued.push([method, args]);
  }
  function flush() {
    var pending = queued;
    queued = [];
    pending.forEach(function (entry) { send(entry[0], entry[1]); });
  }
  var android = {
    showMenu: function () { send('showMenu', []); },
    showProfile: function () { send('showProfile', []); },
    openAppSettings: function () { send('openAppSettings', []); },
    openSupportTickets: function () { send('openSupportTickets', []); },
    openCouponSearch: function () { send('openCouponSearch', []); },
    logout: function () { send('logout', []); },
    handleCanvasImage: function (data) { send('handleCanvasImage', [data]); },
    handleCanvasShare: function (data) { send('handleCanvasShare', [data]); }
  };
  try {
    Object.defineProperty(window, 'Android', {
      configurable: true,
      enumerable: false,
      value: android,
      writable: false
    });
  } catch (_) {
    window.Android = android;
  }
  window.addEventListener('flutterInAppWebViewPlatformReady', flush, { once: true });
  flush();
})();''';
}
