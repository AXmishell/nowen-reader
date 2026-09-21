import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_error.dart';
import '../../data/api/auth_api.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/animations.dart';
import 'auth_config_draft.dart';
import 'auth_security_oidc_section.dart';
import 'auth_security_sections.dart';
import 'auth_security_widgets.dart';

/// 认证与安全配置页面（管理员）。
///
/// 覆盖 SMTP / 邮箱验证策略 / TOTP 策略 / OIDC 配置；保存时只提交被修改
/// 的字段，空密码与空 Client Secret 保持服务端已存值。
class AuthSecurityScreen extends ConsumerStatefulWidget {
  const AuthSecurityScreen({super.key});

  @override
  ConsumerState<AuthSecurityScreen> createState() =>
      _AuthSecurityScreenState();
}

class _AuthSecurityScreenState extends ConsumerState<AuthSecurityScreen> {
  final _draft = AuthConfigDraft();

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  String? _message;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════
  // ─── 加载 / 保存 / 测试 ───
  // ═══════════════════════════════════════════════

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context);
    try {
      final data = await ref.read(authApiProvider).getAuthConfig();
      if (!mounted) return;
      setState(() {
        _draft.loadFrom(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = '${l10n.loadFailed}: ${apiErrorMessage(e)}';
        _isError = true;
      });
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final error = _draft.validate(l10n);
    if (error != null) {
      setState(() {
        _message = error;
        _isError = true;
      });
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ref.read(authApiProvider).updateAuthConfig(_draft.buildBody());
      if (!mounted) return;
      setState(() {
        _saving = false;
        _draft.markSaved();
        _message = l10n.saved;
        _isError = false;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_isError) setState(() => _message = null);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = '${l10n.saveFailed}: ${apiErrorMessage(e)}';
        _isError = true;
      });
    }
  }

  Future<void> _sendTest() async {
    final l10n = AppLocalizations.of(context);
    final to = _draft.testRecipientCtrl.text.trim();
    if (to.isEmpty) {
      setState(() {
        _message = '${l10n.smtpTestRecipient}: ${l10n.requiredField}';
        _isError = true;
      });
      return;
    }

    setState(() {
      _testing = true;
      _message = null;
    });
    try {
      await ref.read(authApiProvider).sendSmtpTest(to);
      if (!mounted) return;
      setState(() {
        _testing = false;
        _message = l10n.smtpTestSuccess;
        _isError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _message = '${l10n.smtpTestFailed}: ${apiErrorMessage(e)}';
        _isError = true;
      });
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).copiedToClipboard)),
    );
  }

  /// 子区块修改草稿后触发重建（开关 / 选择器需要刷新显示）。
  void _onChanged() => setState(() {});

  // ═══════════════════════════════════════════════
  // ─── 构建 ───
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.authSecurity)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authSecurity)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SlideAndFade(
            delay: const Duration(milliseconds: 100),
            child: SmtpConfigSection(
              draft: _draft,
              onChanged: _onChanged,
              testing: _testing,
              onSendTest: _sendTest,
            ),
          ),
          const SizedBox(height: 16),
          SlideAndFade(
            delay: const Duration(milliseconds: 150),
            child: EmailPolicySection(draft: _draft, onChanged: _onChanged),
          ),
          const SizedBox(height: 16),
          SlideAndFade(
            delay: const Duration(milliseconds: 200),
            child: TotpPolicySection(draft: _draft, onChanged: _onChanged),
          ),
          const SizedBox(height: 16),
          SlideAndFade(
            delay: const Duration(milliseconds: 250),
            child: OidcConfigSection(
              draft: _draft,
              onChanged: _onChanged,
              onCopy: _copy,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? '保存中...' : l10n.save),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            AuthMessageBar(message: _message!, isError: _isError),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
