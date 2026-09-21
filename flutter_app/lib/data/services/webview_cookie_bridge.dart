import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../api/api_client.dart';

/// 会话 Cookie 名，与服务端 `middleware.SessionCookie` 保持一致。
const String kSessionCookieName = 'nowen_session';

/// 当前平台是否支持 WebView Cookie 桥接。
///
/// 只有 Android / iOS / macOS 有原生 WebView 实现；桌面与 Web 平台直接走
/// 普通 HTTP 登录（Web 环境由浏览器管理 Cookie）。
bool get isWebViewCookieBridgeSupported {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

/// 跨平台 Cookie 管理器入口。
///
/// 直接使用 `webview_flutter` 的 `WebViewCookieManager` 门面：它会按当前平台
/// 转发到底层 `webview_flutter_android` / `webview_flutter_wkwebview` 实现，
/// 二者都直接读写系统 WebView 的原生 Cookie 存储，因此 HttpOnly 的
/// `nowen_session` 同样可读（要求 android >= 4.12.0、wkwebview >= 3.25.0）。
WebViewCookieManager createWebViewCookieManager() {
  if (!isWebViewCookieBridgeSupported) {
    throw UnsupportedError('OIDC WebView 登录不支持当前平台：$defaultTargetPlatform');
  }
  return WebViewCookieManager();
}

/// 读取 WebView 原生 Cookie 存储中 [origin] 对应的会话 Cookie 值。
///
/// 返回 `null` 表示尚未拿到会话 Cookie（流程未完成或失败）。
Future<String?> readSessionCookie(Uri origin) async {
  final cookies =
      await createWebViewCookieManager().getCookies(domain: origin);
  String? value;
  for (final cookie in cookies) {
    if (cookie.name == kSessionCookieName && cookie.value.isNotEmpty) {
      // 同名 Cookie 可能因 Path 不同存在多条，取最后一条（最新写入）。
      value = cookie.value;
    }
  }
  return value;
}

/// 把 App 自己 `PersistCookieJar` 中的会话 Cookie 注入 WebView。
///
/// 账户关联（`/auth/oidc/link`）需要请求携带当前登录会话，而原生 WebView 与
/// Dio 的 CookieJar 互不共享，因此必须在加载前手动注入。找不到会话 Cookie 时
/// 抛出 [StateError]，由调用方提示重新登录。
Future<void> injectAppSessionCookie(Uri origin) async {
  final cookies = await persistCookieJar.loadForRequest(origin);
  Cookie? session;
  for (final cookie in cookies) {
    if (cookie.name == kSessionCookieName && cookie.value.isNotEmpty) {
      session = cookie;
    }
  }
  if (session == null) {
    throw StateError('未找到可注入的会话 Cookie');
  }

  // WebViewCookie 的 domain 统一传真实主机名：Android 实现会据此拼接 URL
  // 交给原生 CookieManager，iOS/macOS 则直接写入 WKHTTPCookieStore。
  final cookiePath = session.path;
  await createWebViewCookieManager().setCookie(WebViewCookie(
    name: session.name,
    value: session.value,
    domain: origin.host,
    path: (cookiePath != null && cookiePath.isNotEmpty) ? cookiePath : '/',
  ));
}

/// 把 WebView 中拿到的会话 Cookie 写回 App 的 `PersistCookieJar`。
///
/// 与服务端 `SetSessionCookie` 保持一致：host-only（不写 domain），Path 取
/// `BASE_PATH`（应用根路径去掉结尾的 `/`），这样会替换普通登录留下的同名
/// Cookie 而不是产生重复项。只写入约定名称的会话值，不记录、不落盘到其它位置。
Future<void> persistSessionCookie(Uri origin, String value) async {
  var basePath = origin.path;
  if (basePath.length > 1 && basePath.endsWith('/')) {
    basePath = basePath.substring(0, basePath.length - 1);
  }
  if (basePath.isEmpty) basePath = '/';

  final cookie = Cookie(kSessionCookieName, value)
    ..path = basePath
    ..httpOnly = true
    ..secure = origin.scheme == 'https';
  await persistCookieJar.saveFromResponse(origin, [cookie]);
}
