import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/app_localizations.dart';
import 'security_widgets.dart';

/// ─── TOTP 扫码设置流程 ───
/// 展示二维码与密钥，收集验证码后启用。
class TotpSetupFlow extends StatelessWidget {
  final String secret;
  final String otpauthUrl;
  final TextEditingController codeCtrl;
  final bool busy;
  final VoidCallback onEnable;
  final VoidCallback onCancel;
  final ValueChanged<String> onCopy;

  const TotpSetupFlow({
    super.key,
    required this.secret,
    required this.otpauthUrl,
    required this.codeCtrl,
    required this.busy,
    required this.onEnable,
    required this.onCancel,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.totpSetupDesc,
          style:
              TextStyle(fontSize: 12, height: 1.4, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (otpauthUrl.isNotEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: otpauthUrl,
                version: QrVersions.auto,
                size: 170,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (secret.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  secret,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: cs.onSurface,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.copy,
                onPressed: () => onCopy(secret),
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
        const SizedBox(height: 10),
        SecurityTextField(
          controller: codeCtrl,
          hint: l10n.totpCodeOrRecoveryHint,
          keyboardType: TextInputType.number,
          onSubmitted: (_) => onEnable(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : onEnable,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(l10n.totpEnable),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: busy ? null : onCancel,
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ],
    );
  }
}

/// ─── 一次性恢复码警告面板 ───
class TotpRecoveryPanel extends StatelessWidget {
  final List<String> codes;
  final ValueChanged<String> onCopy;
  final VoidCallback onDismiss;

  const TotpRecoveryPanel({
    super.key,
    required this.codes,
    required this.onCopy,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: cs.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.recoveryCodes,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.recoveryCodesDesc,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.recoveryCodesWarning,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.error,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final code in codes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      code,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => onCopy(codes.join('\n')),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text(l10n.copyAll),
              ),
              const Spacer(),
              TextButton(
                onPressed: onDismiss,
                child: Text(l10n.recoveryCodesSaved),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
