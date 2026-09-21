import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_error.dart';
import '../../data/api/auth_api.dart';
import '../../data/providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import 'security_widgets.dart';
import 'totp_parts.dart';

/// 两步验证（TOTP）区块：查看状态、扫码启用、一次性恢复码、关闭。
class TotpSection extends ConsumerStatefulWidget {
  const TotpSection({super.key});

  @override
  ConsumerState<TotpSection> createState() => _TotpSectionState();
}

class _TotpSectionState extends ConsumerState<TotpSection> {
  final _codeCtrl = TextEditingController();

  bool _enabled = false;
  bool _statusLoading = true;
  bool _setupOpen = false;
  bool _busy = false;
  String _secret = '';
  String _otpauthUrl = '';
  List<String> _recoveryCodes = const [];
  String? _message;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _enabled = ref.read(authProvider).user?.totpEnabled == true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatus();
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final data = await ref.read(authApiProvider).totpStatus();
      if (!mounted) return;
      setState(() {
        _enabled = data['enabled'] == true;
        _statusLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _statusLoading = false);
    }
  }

  Future<void> _startSetup() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final data = await ref.read(authApiProvider).totpSetup();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _setupOpen = true;
        _secret = data['secret']?.toString() ?? '';
        _otpauthUrl = data['otpauthUrl']?.toString() ?? '';
        _codeCtrl.clear();
        _recoveryCodes = const [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = apiErrorMessage(e);
        _isError = true;
      });
    }
  }

  Future<void> _enable() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || _busy) return;

    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final data = await ref.read(authApiProvider).totpEnable(code);
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _setupOpen = false;
        _enabled = true;
        _recoveryCodes = (data['recoveryCodes'] as List?)
                ?.map((item) => item.toString())
                .toList() ??
            const [];
        _message = l10n.totpEnabledSuccess;
        _isError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = apiErrorMessage(e);
        _isError = true;
      });
    }
  }

  Future<void> _promptDisable() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.totpDisable),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.totpDisablePrompt, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration:
                  InputDecoration(hintText: l10n.totpCodeOrRecoveryHint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (code == null || code.isEmpty || !mounted) return;
    await _disable(code);
  }

  Future<void> _disable(String code) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(authApiProvider).totpDisable(code);
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _enabled = false;
        _recoveryCodes = const [];
        _message = l10n.totpDisabledSuccess;
        _isError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = apiErrorMessage(e);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SecuritySection(
      title: l10n.twoFactorAuth,
      icon: Icons.security_rounded,
      trailing: _statusLoading
          ? null
          : SecurityBadge(
              text: _enabled ? l10n.twoFactorEnabled : l10n.twoFactorDisabled,
              ok: _enabled,
            ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_recoveryCodes.isNotEmpty) ...[
                TotpRecoveryPanel(
                  codes: _recoveryCodes,
                  onCopy: _copy,
                  onDismiss: () => setState(() => _recoveryCodes = const []),
                ),
                const SizedBox(height: 12),
              ],
              if (_setupOpen)
                TotpSetupFlow(
                  secret: _secret,
                  otpauthUrl: _otpauthUrl,
                  codeCtrl: _codeCtrl,
                  busy: _busy,
                  onEnable: _enable,
                  onCancel: () => setState(() {
                    _setupOpen = false;
                    _codeCtrl.clear();
                  }),
                  onCopy: _copy,
                )
              else
                ..._buildOverview(l10n),
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

  List<Widget> _buildOverview(AppLocalizations l10n) {
    if (_enabled) {
      return [
        OutlinedButton.icon(
          onPressed: _busy ? null : _promptDisable,
          icon: const Icon(Icons.block_rounded, size: 18),
          label: Text(l10n.totpDisable),
        ),
      ];
    }

    return [
      FilledButton.tonalIcon(
        onPressed: _busy ? null : _startSetup,
        icon: const Icon(Icons.qr_code_2_rounded, size: 18),
        label: Text(l10n.setup),
      ),
    ];
  }
}
