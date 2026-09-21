import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_error.dart';
import '../../data/api/auth_api.dart';
import '../../data/providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import 'email_flow_form.dart';
import 'security_widgets.dart';

/// 邮箱绑定 / 验证区块。
///
/// 未绑定邮箱时提供「绑定邮箱」流程；已绑定时提供「验证邮箱」与「更换邮箱」。
/// 两个流程共用发送验证码 + 60 秒冷却 + 验证码校验的交互。
class EmailSection extends ConsumerStatefulWidget {
  const EmailSection({super.key});

  @override
  ConsumerState<EmailSection> createState() => _EmailSectionState();
}

class _EmailSectionState extends ConsumerState<EmailSection> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  /// 当前流程：空 | `bind`（绑定 / 换绑）| `verify`（验证已有邮箱）。
  String _flow = '';
  int _cooldown = 0;
  Timer? _timer;
  bool _sending = false;
  bool _submitting = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _startFlow(String flow) async {
    final user = ref.read(authProvider).user;
    setState(() {
      _flow = flow;
      _message = null;
      _codeCtrl.clear();
      _emailCtrl.text = flow == 'verify' ? (user?.email ?? '') : '';
    });
    if (flow == 'verify') await _sendCode();
  }

  Future<void> _sendCode() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailCtrl.text.trim();
    if (_flow.isEmpty || email.isEmpty || _cooldown > 0 || _sending) return;

    setState(() => _sending = true);
    try {
      final api = ref.read(authApiProvider);
      if (_flow == 'bind') {
        await api.sendEmailBindCode(email);
      } else {
        await api.sendEmailCode(email, 'verify');
      }
      if (!mounted) return;
      _startCooldown();
      setState(() {
        _message = l10n.codeSent;
        _isError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = apiErrorMessage(e);
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (email.isEmpty || code.isEmpty || _submitting) return;

    final isBind = _flow == 'bind';
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      final api = ref.read(authApiProvider);
      if (isBind) {
        await api.verifyEmailBind(email, code);
      } else {
        await api.verifyEmailCode(email, code);
      }
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _submitting = false;
        _flow = '';
        _cooldown = 0;
        _message = isBind ? l10n.bindEmailSuccess : l10n.emailVerifiedSuccess;
        _isError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _message = apiErrorMessage(e);
        _isError = true;
      });
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _cooldown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldown = 0);
        return;
      }
      setState(() => _cooldown -= 1);
    });
  }

  void _cancelFlow() {
    _timer?.cancel();
    setState(() {
      _flow = '';
      _cooldown = 0;
      _message = null;
      _emailCtrl.clear();
      _codeCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final email = user?.email ?? '';
    final verified = user?.emailVerified == true;

    return SecuritySection(
      title: l10n.securityEmail,
      icon: Icons.mail_outline_rounded,
      trailing: email.isEmpty
          ? null
          : SecurityBadge(
              text: verified ? l10n.emailVerified : l10n.emailNotVerified,
              ok: verified,
            ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_flow.isEmpty)
                ..._buildOverview(cs, l10n, email, verified)
              else
                EmailFlowForm(
                  isBind: _flow == 'bind',
                  emailCtrl: _emailCtrl,
                  codeCtrl: _codeCtrl,
                  cooldown: _cooldown,
                  sending: _sending,
                  submitting: _submitting,
                  onSendCode: _sendCode,
                  onVerify: _verify,
                  onCancel: _cancelFlow,
                ),
              if (_message != null) ...[
                const SizedBox(height: 10),
                SecurityMessage(message: _message!, isError: _isError),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildOverview(
      ColorScheme cs, AppLocalizations l10n, String email, bool verified) {
    if (email.isEmpty) {
      return [
        Text(
          l10n.emailNotBound,
          style: TextStyle(fontSize: 13, color: cs.onSurface),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.bindEmailDesc,
          style: TextStyle(
            fontSize: 11,
            height: 1.4,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: () => _startFlow('bind'),
          icon: const Icon(Icons.add_link_rounded, size: 18),
          label: Text(l10n.bindEmail),
        ),
      ];
    }

    return [
      Text(
        email,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
      if (!verified) ...[
        const SizedBox(height: 6),
        Text(
          l10n.emailUnverifiedHint,
          style: TextStyle(
            fontSize: 11,
            height: 1.4,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (!verified)
            FilledButton.tonalIcon(
              onPressed: () => _startFlow('verify'),
              icon: const Icon(Icons.mark_email_read_rounded, size: 18),
              label: Text(l10n.verifyEmail),
            ),
          OutlinedButton.icon(
            onPressed: () => _startFlow('bind'),
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: Text(l10n.changeEmail),
          ),
        ],
      ),
    ];
  }
}
