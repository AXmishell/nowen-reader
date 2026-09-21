import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// 认证与安全配置的编辑草稿。
///
/// 持有全部输入控制器与「脏字段」标记；[buildBody] 只输出被用户修改过的
/// 字段，空密码 / 空 Client Secret 直接省略（服务端保持已存值）。
class AuthConfigDraft {
  // SMTP
  final smtpHostCtrl = TextEditingController();
  final smtpPortCtrl = TextEditingController();
  final smtpUsernameCtrl = TextEditingController();
  final smtpPasswordCtrl = TextEditingController();
  final smtpFromCtrl = TextEditingController();
  final smtpFromNameCtrl = TextEditingController();
  bool smtpEnabled = false;
  bool smtpPasswordSet = false;
  String smtpTlsMode = 'starttls';

  // 邮箱验证策略
  bool emailVerificationRequired = false;
  bool emailCodeLoginEnabled = false;

  // TOTP 策略
  bool totpEnabled = false;
  bool totpRequiredForAdmins = false;
  final totpIssuerCtrl = TextEditingController();

  // OIDC
  bool oidcEnabled = false;
  final oidcIssuerCtrl = TextEditingController();
  final oidcClientIdCtrl = TextEditingController();
  final oidcClientSecretCtrl = TextEditingController();
  final oidcScopesCtrl = TextEditingController();
  final oidcButtonLabelCtrl = TextEditingController();
  bool oidcAutoCreateUsers = false;
  bool oidcClientSecretSet = false;
  String oidcCallbackUrl = '';

  // SMTP 测试邮件
  final testRecipientCtrl = TextEditingController();

  /// 被用户修改过的字段（`section.field` 形式）。
  final Set<String> dirty = {};

  /// 用服务端配置覆盖草稿；密钥字段始终留空。
  void loadFrom(Map<String, dynamic> data) {
    final smtp = _asMap(data['smtp']);
    final totp = _asMap(data['totp']);
    final oidc = _asMap(data['oidc']);

    smtpEnabled = smtp['enabled'] == true;
    smtpHostCtrl.text = smtp['host']?.toString() ?? '';
    final port = smtp['port'];
    smtpPortCtrl.text = (port == null || port == 0) ? '' : port.toString();
    smtpUsernameCtrl.text = smtp['username']?.toString() ?? '';
    smtpPasswordCtrl.clear();
    smtpPasswordSet = smtp['passwordSet'] == true;
    smtpFromCtrl.text = smtp['from']?.toString() ?? '';
    smtpFromNameCtrl.text = smtp['fromName']?.toString() ?? '';
    smtpTlsMode = _normalizeTlsMode(smtp['tlsMode']?.toString());

    emailVerificationRequired = data['emailVerificationRequired'] == true;
    emailCodeLoginEnabled = data['emailCodeLoginEnabled'] == true;

    totpEnabled = totp['enabled'] == true;
    totpRequiredForAdmins = totp['requiredForAdmins'] == true;
    totpIssuerCtrl.text = totp['issuer']?.toString() ?? '';

    oidcEnabled = oidc['enabled'] == true;
    oidcIssuerCtrl.text = oidc['issuerUrl']?.toString() ?? '';
    oidcClientIdCtrl.text = oidc['clientId']?.toString() ?? '';
    oidcClientSecretCtrl.clear();
    oidcClientSecretSet = oidc['clientSecretSet'] == true;
    oidcScopesCtrl.text = oidc['scopes']?.toString() ?? '';
    oidcButtonLabelCtrl.text = oidc['buttonLabel']?.toString() ?? '';
    oidcAutoCreateUsers = oidc['autoCreateUsers'] == true;
    oidcCallbackUrl = oidc['callbackUrl']?.toString() ?? '';

    dirty.clear();
  }

  /// 客户端校验：启用 SMTP 时要求 host + 合法端口，启用 OIDC 时要求
  /// issuerUrl + clientId。
  String? validate(AppLocalizations l10n) {
    if (smtpEnabled) {
      if (smtpHostCtrl.text.trim().isEmpty) {
        return '${l10n.smtpHost}: ${l10n.requiredField}';
      }
      final port = int.tryParse(smtpPortCtrl.text.trim());
      if (port == null || port < 1 || port > 65535) {
        return '${l10n.smtpPort}: ${l10n.invalidPort}';
      }
    }
    if (oidcEnabled) {
      if (oidcIssuerCtrl.text.trim().isEmpty) {
        return '${l10n.oidcIssuerUrl}: ${l10n.requiredField}';
      }
      if (oidcClientIdCtrl.text.trim().isEmpty) {
        return '${l10n.oidcClientId}: ${l10n.requiredField}';
      }
    }
    return null;
  }

  /// 只收集被修改过的字段；空密码 / 空 Client Secret 直接省略。
  Map<String, dynamic> buildBody() {
    final body = <String, dynamic>{};
    final port = int.tryParse(smtpPortCtrl.text.trim());

    final smtp = <String, dynamic>{
      if (dirty.contains('smtp.enabled')) 'enabled': smtpEnabled,
      if (dirty.contains('smtp.host')) 'host': smtpHostCtrl.text.trim(),
      if (dirty.contains('smtp.port') && port != null) 'port': port,
      if (dirty.contains('smtp.username'))
        'username': smtpUsernameCtrl.text.trim(),
      if (dirty.contains('smtp.password') && smtpPasswordCtrl.text.isNotEmpty)
        'password': smtpPasswordCtrl.text,
      if (dirty.contains('smtp.from')) 'from': smtpFromCtrl.text.trim(),
      if (dirty.contains('smtp.fromName'))
        'fromName': smtpFromNameCtrl.text.trim(),
      if (dirty.contains('smtp.tlsMode')) 'tlsMode': smtpTlsMode,
    };
    if (smtp.isNotEmpty) body['smtp'] = smtp;

    final totp = <String, dynamic>{
      if (dirty.contains('totp.enabled')) 'enabled': totpEnabled,
      if (dirty.contains('totp.requiredForAdmins'))
        'requiredForAdmins': totpRequiredForAdmins,
      if (dirty.contains('totp.issuer') && totpIssuerCtrl.text.trim().isNotEmpty)
        'issuer': totpIssuerCtrl.text.trim(),
    };
    if (totp.isNotEmpty) body['totp'] = totp;

    final oidc = <String, dynamic>{
      if (dirty.contains('oidc.enabled')) 'enabled': oidcEnabled,
      if (dirty.contains('oidc.issuerUrl'))
        'issuerUrl': oidcIssuerCtrl.text.trim(),
      if (dirty.contains('oidc.clientId'))
        'clientId': oidcClientIdCtrl.text.trim(),
      if (dirty.contains('oidc.clientSecret') &&
          oidcClientSecretCtrl.text.isNotEmpty)
        'clientSecret': oidcClientSecretCtrl.text,
      if (dirty.contains('oidc.scopes')) 'scopes': oidcScopesCtrl.text.trim(),
      if (dirty.contains('oidc.buttonLabel'))
        'buttonLabel': oidcButtonLabelCtrl.text.trim(),
      if (dirty.contains('oidc.autoCreateUsers'))
        'autoCreateUsers': oidcAutoCreateUsers,
    };
    if (oidc.isNotEmpty) body['oidc'] = oidc;

    if (dirty.contains('emailVerificationRequired')) {
      body['emailVerificationRequired'] = emailVerificationRequired;
    }
    if (dirty.contains('emailCodeLoginEnabled')) {
      body['emailCodeLoginEnabled'] = emailCodeLoginEnabled;
    }
    return body;
  }

  /// 保存成功后清空密钥输入框并刷新 `*Set` 标记与脏标记。
  void markSaved() {
    if (smtpPasswordCtrl.text.isNotEmpty) {
      smtpPasswordSet = true;
      smtpPasswordCtrl.clear();
    }
    if (oidcClientSecretCtrl.text.isNotEmpty) {
      oidcClientSecretSet = true;
      oidcClientSecretCtrl.clear();
    }
    dirty.clear();
  }

  void dispose() {
    smtpHostCtrl.dispose();
    smtpPortCtrl.dispose();
    smtpUsernameCtrl.dispose();
    smtpPasswordCtrl.dispose();
    smtpFromCtrl.dispose();
    smtpFromNameCtrl.dispose();
    totpIssuerCtrl.dispose();
    oidcIssuerCtrl.dispose();
    oidcClientIdCtrl.dispose();
    oidcClientSecretCtrl.dispose();
    oidcScopesCtrl.dispose();
    oidcButtonLabelCtrl.dispose();
    testRecipientCtrl.dispose();
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static String _normalizeTlsMode(String? mode) {
    const allowed = {'none', 'starttls', 'ssl'};
    return allowed.contains(mode) ? mode! : 'starttls';
  }
}
