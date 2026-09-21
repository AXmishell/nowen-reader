import '../../l10n/app_localizations.dart';

/// OIDC WebView 流程的终态。
enum OidcWebViewStatus {
  /// 会话已建立，调用方应刷新用户并跳转首页。
  session,

  /// 需要 TOTP 二次验证，携带 [OidcWebViewResult.challengeId]。
  totp,

  /// 流程失败，携带服务端短码或本地错误码。
  error,
}

/// WebView 授权流程回传给调用方的结果。
class OidcWebViewResult {
  final OidcWebViewStatus status;

  /// TOTP 二次验证挑战 ID（仅 [OidcWebViewStatus.totp]）。
  final String? challengeId;

  /// 错误短码（仅 [OidcWebViewStatus.error]）。
  final String? errorCode;

  const OidcWebViewResult._({
    required this.status,
    this.challengeId,
    this.errorCode,
  });

  const OidcWebViewResult.session() : this._(status: OidcWebViewStatus.session);

  const OidcWebViewResult.totp(String challengeId)
      : this._(status: OidcWebViewStatus.totp, challengeId: challengeId);

  const OidcWebViewResult.error(String errorCode)
      : this._(status: OidcWebViewStatus.error, errorCode: errorCode);
}

/// 把服务端 `oidc_error` 短码（或本地码）映射为可展示文案。
String oidcErrorText(AppLocalizations l10n, String? code) {
  switch (code) {
    case 'state':
      return l10n.oidcErrorState;
    case 'provider':
      return l10n.oidcErrorProvider;
    case 'code':
      return l10n.oidcErrorCode;
    case 'exchange':
      return l10n.oidcErrorExchange;
    case 'nonce':
      return l10n.oidcErrorNonce;
    case 'claims':
      return l10n.oidcErrorClaims;
    case 'not_linked':
      return l10n.oidcErrorNotLinked;
    case 'link_conflict':
      return l10n.oidcErrorLinkConflict;
    case 'link_failed':
      return l10n.oidcErrorLinkFailed;
    case 'provision_failed':
      return l10n.oidcErrorProvisionFailed;
    case 'internal':
      return l10n.oidcErrorInternal;
    case 'network':
      return l10n.oidcErrorNetwork;
    case 'no_session':
      return l10n.oidcErrorNoSession;
    case 'unsupported':
      return l10n.oidcErrorUnsupported;
    default:
      return l10n.oidcErrorGeneric;
  }
}
