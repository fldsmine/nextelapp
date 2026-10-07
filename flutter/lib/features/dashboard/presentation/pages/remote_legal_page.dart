import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/providers.dart';
import '../../../../app/theme/app_theme.dart';

class RemoteLegalPage extends ConsumerStatefulWidget {
  const RemoteLegalPage({
    required this.title,
    required this.path,
    super.key,
  });

  final String title;
  final String path;

  @override
  ConsumerState<RemoteLegalPage> createState() => _RemoteLegalPageState();
}

class _RemoteLegalPageState extends ConsumerState<RemoteLegalPage> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _loading = true;
  bool _failed = false;

  AppConfig get _config => ref.read(appConfigProvider);

  @override
  Widget build(BuildContext context) {
    final uri = _config.webOrigin.resolve('/${widget.path}');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (_controller != null && await _controller!.canGoBack()) {
              await _controller!.goBack();
            } else if (context.mounted) {
              context.pop();
            }
          },
        ),
        bottom: _loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              )
            : null,
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(uri.toString())),
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
              useShouldOverrideUrlLoading: true,
              javaScriptBridgeEnabled: false,
              isInspectable: false,
            ),
            onWebViewCreated: (controller) => _controller = controller,
            shouldOverrideUrlLoading: (controller, action) async {
              final rawUrl = action.request.url?.toString();
              final requestedUri = rawUrl == null ? null : Uri.tryParse(rawUrl);
              if (requestedUri == null || requestedUri.userInfo.isNotEmpty) {
                return NavigationActionPolicy.CANCEL;
              }
              if (_config.isTrustedWebUri(requestedUri)) {
                return NavigationActionPolicy.ALLOW;
              }
              if (!action.isForMainFrame) return NavigationActionPolicy.CANCEL;
              if (const {'http', 'https', 'mailto', 'tel'}
                  .contains(requestedUri.scheme.toLowerCase())) {
                try {
                  await launchUrl(
                    requestedUri,
                    mode: LaunchMode.externalApplication,
                  );
                } catch (_) {
                  // No matching external activity is a safe no-op.
                }
              }
              return NavigationActionPolicy.CANCEL;
            },
            onLoadStart: (controller, url) {
              if (mounted) setState(() {
                _loading = true;
                _failed = false;
              });
            },
            onProgressChanged: (controller, progress) {
              if (mounted) setState(() => _progress = progress / 100);
            },
            onLoadStop: (controller, url) {
              if (mounted) setState(() {
                _loading = false;
                _failed = false;
              });
            },
            onReceivedError: (controller, request, error) {
              if (request.isForMainFrame == true && mounted) {
                setState(() {
                  _loading = false;
                  _failed = true;
                });
              }
            },
            onReceivedHttpError: (controller, request, response) {
              if (request.isForMainFrame == true && mounted) {
                setState(() {
                  _loading = false;
                  _failed = true;
                });
              }
            },
            onReceivedServerTrustAuthRequest: (controller, challenge) async =>
                ServerTrustAuthResponse(
              action: ServerTrustAuthResponseAction.CANCEL,
            ),
          ),
          if (_failed)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 42,
                          color: NextelPalette.muted,
                        ),
                        const SizedBox(height: 12),
                        const Text('Could not load this page.'),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () async {
                            setState(() {
                              _loading = true;
                              _failed = false;
                            });
                            await _controller?.loadUrl(
                              urlRequest: URLRequest(url: WebUri(uri.toString())),
                            );
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
