import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/api/api_client.dart';
import '../../data/services/webview_cookie_bridge.dart';
import '../../l10n/app_localizations.dart';
import 'oidc_result.dart';

/// WebView 流程模式：登录（登录页）或关联（账户安全页）。
enum OidcWebViewMode { login, link }

/// 应用内 WebView 完成 OIDC 授权码流程。
///
/// 服务端回调会 302 到 SPA 根地址并携带 `?oidc=ok`、
/// `?oidc=totp&challengeId=…` 或 `?oidc_error=…`；本页拦截该终态跳转，读取
/// WebView 原生 Cookie 存储中的会话 Cookie，写回 App 的 CookieJar 后 pop
/// 返回 [OidcWebViewResult]。
class OidcWebViewScreen extends ConsumerStatefulWidget {
  final OidcWebViewMode mode;

  const OidcWebViewScreen({super.key, required this.mode});

  @override
  ConsumerState<OidcWebViewScreen> createState() => _OidcWebViewScreenState();
}

class _OidcWebViewScreenState extends ConsumerState<OidcWebViewScreen> {
  WebViewController? _controller;
  late final Uri _origin;
  late final String _startUrl;

  bool _loading = true;
  bool _handled = false;
  bool _popped = false;
  String? _errorCode;

  @override
  void initState() {
    super.initState();
    final client = ref.read(apiClientProvider);
    _origin = Uri.parse('${client.baseUrl}/');
    final apiBase = '${client.baseUrl}/api';
    _startUrl = widget.mode == OidcWebViewMode.link
        ? '$apiBase/auth/oidc/link'
        : '$apiBase/auth/oidc/login';

    if (!isWebViewCookieBridgeSupported) {
      _loading = false;
      _errorCode = 'unsupported';
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => _setLoading(true),
        onPageFinished: (url) {
          _setLoading(false);
          _handleUrl(url);
        },
        onNavigationRequest: (request) {
          if (!request.isMainFrame) return NavigationDecision.navigate;
          if (_isTerminal(request.url)) {
            _handleUrl(request.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == false) return;
          _fail('network');
        },
        // 关联模式下若注入的会话失效，`/auth/oidc/link` 会直接返回 401 JSON，
        // 不会再有终态跳转，这里主动提示重新登录。登录模式下 401 属于 IdP 自身
        // 页面，交由页面处理。
        onHttpError: (error) {
          if (widget.mode == OidcWebViewMode.link &&
              error.response?.statusCode == 401) {
            _fail('no_session');
          }
        },
      ));
    _boot();
  }

  /// 启动流程：清空 WebView 残留 Cookie，关联模式下注入 App 会话后加载。
  Future<void> _boot() async {
    if (_controller == null) return;
    try {
      await createWebViewCookieManager().clearCookies();
      if (widget.mode == OidcWebViewMode.link) {
        await injectAppSessionCookie(_origin);
      }
      await _controller!.loadRequest(Uri.parse(_startUrl));
    } on UnsupportedError {
      _fail('unsupported');
    } on StateError {
      _fail('no_session');
    } catch (_) {
      _fail('internal');
    }
  }

  void _setLoading(bool value) {
    if (!mounted || _loading == value) return;
    setState(() => _loading = value);
  }

  void _fail(String code) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _errorCode ??= code;
    });
  }

  /// 判断 URL 是否为服务端回调终态（同源且带 `oidc` / `oidc_error` 参数）。
  bool _isTerminal(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (!uri.isScheme('http') && !uri.isScheme('https')) return false;
    if (uri.host != _origin.host || uri.port != _origin.port) return false;
    return uri.queryParameters.containsKey('oidc') ||
        uri.queryParameters.containsKey('oidc_error');
  }

  Future<void> _handleUrl(String url) async {
    if (_handled || !_isTerminal(url)) return;
    _handled = true;

    final params = Uri.parse(url).queryParameters;
    final error = params['oidc_error'];
    if (error != null && error.isNotEmpty) {
      _finish(OidcWebViewResult.error(error));
      return;
    }

    final status = params['oidc'] ?? '';
    if (status == 'totp') {
      final challengeId = params['challengeId'] ?? '';
      _finish(challengeId.isEmpty
          ? const OidcWebViewResult.error('state')
          : OidcWebViewResult.totp(challengeId));
      return;
    }
    if (status != 'ok') {
      _finish(const OidcWebViewResult.error('internal'));
      return;
    }

    // 会话 Cookie 已由回调响应写入 WebView 原生存储，读出后写回 App 的
    // PersistCookieJar，后续 Dio 请求即可携带该会话。
    try {
      final value = await _readSessionCookieWithRetry();
      if (value == null || value.isEmpty) {
        _finish(const OidcWebViewResult.error('no_session'));
        return;
      }
      await persistSessionCookie(_origin, value);
      _finish(const OidcWebViewResult.session());
    } catch (_) {
      _finish(const OidcWebViewResult.error('internal'));
    }
  }

  /// 读取会话 Cookie；iOS 的 `WKHTTPCookieStore` 写入略滞后于导航回调，
  /// 因此做有限次重试（最多约 600ms）。
  Future<String?> _readSessionCookieWithRetry() async {
    String? value;
    for (var attempt = 0; attempt < 5; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      value = await readSessionCookie(_origin);
      if (value != null && value.isNotEmpty) break;
    }
    return value;
  }

  void _finish(OidcWebViewResult result) {
    if (!mounted || _popped) return;
    _popped = true;
    Navigator.of(context).pop(result);
  }

  void _retry() {
    if (_controller == null) return;
    setState(() {
      _handled = false;
      _popped = false;
      _errorCode = null;
      _loading = true;
    });
    _boot();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == OidcWebViewMode.link
            ? l10n.linkAccount
            : l10n.ssoLogin),
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _errorCode != null || controller == null
                ? _buildError(l10n)
                : WebViewWidget(controller: controller),
          ),
        ],
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 44, color: cs.error),
            const SizedBox(height: 14),
            Text(
              oidcErrorText(l10n, _errorCode),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: cs.onSurface),
            ),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
