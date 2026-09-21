import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'security_widgets.dart';

/// 邮箱绑定 / 验证的验证码表单。
class EmailFlowForm extends StatelessWidget {
  final bool isBind;
  final TextEditingController emailCtrl;
  final TextEditingController codeCtrl;
  final int cooldown;
  final bool sending;
  final bool submitting;
  final VoidCallback onSendCode;
  final VoidCallback onVerify;
  final VoidCallback onCancel;

  const EmailFlowForm({
    super.key,
    required this.isBind,
    required this.emailCtrl,
    required this.codeCtrl,
    required this.cooldown,
    required this.sending,
    required this.submitting,
    required this.onSendCode,
    required this.onVerify,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isBind ? l10n.bindEmailDesc : l10n.verifyEmailDesc,
          style:
              TextStyle(fontSize: 12, height: 1.4, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SecurityTextField(
          controller: emailCtrl,
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          readOnly: !isBind,
        ),
        const SizedBox(height: 10),
        SecurityTextField(
          controller: codeCtrl,
          hint: l10n.emailCode,
          keyboardType: TextInputType.number,
          onSubmitted: (_) => onVerify(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: submitting ? null : onVerify,
                icon: submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(l10n.verify),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: (cooldown > 0 || sending) ? null : onSendCode,
              child: Text(
                cooldown > 0 ? '${l10n.resendCode} ($cooldown)' : l10n.sendCode,
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: submitting ? null : onCancel,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text(l10n.cancel),
          ),
        ),
      ],
    );
  }
}
