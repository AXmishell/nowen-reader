import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/animations.dart';
import 'auth_controls.dart';
import 'auth_widgets.dart';

/// 登录第二步：TOTP 验证码 / 恢复码校验。
///
/// 校验通过后由 [onSuccess] 决定跳转；[onBack] 返回第一因子表单。
class TotpStepView extends ConsumerStatefulWidget {
  final String challengeId;
  final bool mustSetupTotp;
  final VoidCallback onSuccess;
  final VoidCallback onBack;

  const TotpStepView({
    super.key,
    required this.challengeId,
    required this.mustSetupTotp,
    required this.onSuccess,
    required this.onBack,
  });

  @override
  ConsumerState<TotpStepView> createState() => _TotpStepViewState();
}

class _TotpStepViewState extends ConsumerState<TotpStepView> {
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;

    HapticFeedback.lightImpact();
    ref.read(authProvider.notifier).clearError();
    final ok = await ref
        .read(authProvider.notifier)
        .verifyTotp(widget.challengeId, code);
    if (ok && mounted) widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return SlideAndFade(
      duration: const Duration(milliseconds: 400),
      child: AuthCard(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.shield_outlined, size: 26, color: cs.primary),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.totpTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.totpHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: cs.onSurfaceVariant.withOpacity(0.6),
              ),
            ),
            if (widget.mustSetupTotp) ...[
              const SizedBox(height: 14),
              _buildHintPanel(cs, l10n.totpMustSetupHint),
            ],
            const SizedBox(height: 18),
            LoginTextField(
              controller: _codeCtrl,
              label: l10n.totpCode,
              hint: l10n.totpCodeOrRecoveryHint,
              icon: Icons.password_rounded,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _verify(),
            ),
            if (authState.error != null) ...[
              const SizedBox(height: 12),
              LoginErrorBanner(error: authState.error!),
            ],
            const SizedBox(height: 18),
            LoginSubmitButton(
              label: l10n.verify,
              icon: Icons.verified_rounded,
              loading: authState.isLoading,
              onTap: _verify,
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: authState.isLoading ? null : widget.onBack,
              child: Text(l10n.backToLogin),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintPanel(ColorScheme cs, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
