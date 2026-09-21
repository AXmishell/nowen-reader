import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'auth_config_draft.dart';
import 'auth_security_widgets.dart';

/// ─── OIDC 登录配置 ───
class OidcConfigSection extends StatelessWidget {
  final AuthConfigDraft draft;
  final VoidCallback onChanged;
  final ValueChanged<String> onCopy;

  const OidcConfigSection({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return AuthSectionCard(
      title: l10n.oidcSection,
      icon: Icons.hub_outlined,
      children: [
        AuthSwitchTile(
          title: l10n.oidcEnabled,
          value: draft.oidcEnabled,
          onChanged: (value) {
            draft.oidcEnabled = value;
            draft.dirty.add('oidc.enabled');
            onChanged();
          },
        ),
        AuthField(
          controller: draft.oidcIssuerCtrl,
          label: l10n.oidcIssuerUrl,
          hint: 'https://id.example.com',
          onChanged: (_) => draft.dirty.add('oidc.issuerUrl'),
        ),
        AuthField(
          controller: draft.oidcClientIdCtrl,
          label: l10n.oidcClientId,
          hint: 'nowen-reader',
          onChanged: (_) => draft.dirty.add('oidc.clientId'),
        ),
        AuthField(
          controller: draft.oidcClientSecretCtrl,
          label: l10n.oidcClientSecret,
          hint: draft.oidcClientSecretSet ? l10n.secretKeptHint : '',
          obscureText: true,
          onChanged: (_) => draft.dirty.add('oidc.clientSecret'),
        ),
        AuthField(
          controller: draft.oidcScopesCtrl,
          label: l10n.oidcScopes,
          hint: 'openid profile email',
          onChanged: (_) => draft.dirty.add('oidc.scopes'),
        ),
        AuthField(
          controller: draft.oidcButtonLabelCtrl,
          label: l10n.oidcButtonLabel,
          hint: l10n.ssoLogin,
          onChanged: (_) => draft.dirty.add('oidc.buttonLabel'),
        ),
        AuthSwitchTile(
          title: l10n.oidcAutoCreateUsers,
          value: draft.oidcAutoCreateUsers,
          onChanged: (value) {
            draft.oidcAutoCreateUsers = value;
            draft.dirty.add('oidc.autoCreateUsers');
            onChanged();
          },
        ),
        _buildCallbackRow(cs, l10n),
      ],
    );
  }

  Widget _buildCallbackRow(ColorScheme cs, AppLocalizations l10n) {
    final callbackUrl = draft.oidcCallbackUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.oidcCallbackUrl,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: cs.outlineVariant.withOpacity(0.3)),
                  ),
                  child: SelectableText(
                    callbackUrl.isEmpty ? '—' : callbackUrl,
                    style: TextStyle(fontSize: 13, color: cs.onSurface),
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.copy,
                onPressed: callbackUrl.isEmpty ? null : () => onCopy(callbackUrl),
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.oidcCallbackHint,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
