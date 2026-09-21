import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 登录页 SSO 区域：「或」分隔线 + 每个 OIDC 提供方一个按钮。
class OidcLoginButtons extends StatelessWidget {
  final List<Map<String, dynamic>> providers;
  final bool enabled;
  final VoidCallback onPressed;

  const OidcLoginButtons({
    super.key,
    required this.providers,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: cs.outlineVariant.withOpacity(0.4))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                l10n.orContinueWith,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
            ),
            Expanded(child: Divider(color: cs.outlineVariant.withOpacity(0.4))),
          ],
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < providers.length; i++) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: enabled ? onPressed : null,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(_label(providers[i], l10n)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (i < providers.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  String _label(Map<String, dynamic> provider, AppLocalizations l10n) {
    final label = provider['label']?.toString() ?? '';
    return label.isNotEmpty ? label : l10n.ssoLogin;
  }
}
