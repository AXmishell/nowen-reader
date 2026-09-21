import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'auth_config_draft.dart';
import 'auth_security_widgets.dart';

/// ─── SMTP 配置 ───
class SmtpConfigSection extends StatelessWidget {
  final AuthConfigDraft draft;
  final VoidCallback onChanged;
  final bool testing;
  final VoidCallback onSendTest;

  const SmtpConfigSection({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.testing,
    required this.onSendTest,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return AuthSectionCard(
      title: l10n.smtpSection,
      icon: Icons.email_outlined,
      children: [
        AuthSwitchTile(
          title: l10n.smtpEnabled,
          subtitle: l10n.smtpEnabledHint,
          value: draft.smtpEnabled,
          onChanged: (value) {
            draft.smtpEnabled = value;
            draft.dirty.add('smtp.enabled');
            onChanged();
          },
        ),
        AuthField(
          controller: draft.smtpHostCtrl,
          label: l10n.smtpHost,
          hint: 'smtp.example.com',
          onChanged: (_) => draft.dirty.add('smtp.host'),
        ),
        AuthField(
          controller: draft.smtpPortCtrl,
          label: l10n.smtpPort,
          hint: '587',
          keyboardType: TextInputType.number,
          onChanged: (_) => draft.dirty.add('smtp.port'),
        ),
        AuthField(
          controller: draft.smtpUsernameCtrl,
          label: l10n.username,
          hint: 'user@example.com',
          onChanged: (_) => draft.dirty.add('smtp.username'),
        ),
        AuthField(
          controller: draft.smtpPasswordCtrl,
          label: l10n.password,
          hint: draft.smtpPasswordSet ? l10n.secretKeptHint : '',
          obscureText: true,
          onChanged: (_) => draft.dirty.add('smtp.password'),
        ),
        AuthField(
          controller: draft.smtpFromCtrl,
          label: l10n.smtpFrom,
          hint: 'noreply@example.com',
          onChanged: (_) => draft.dirty.add('smtp.from'),
        ),
        AuthField(
          controller: draft.smtpFromNameCtrl,
          label: l10n.smtpFromName,
          hint: 'NowenReader',
          onChanged: (_) => draft.dirty.add('smtp.fromName'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.smtpTlsMode,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'none',
                    label: Text(l10n.tlsModeNone,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: 'starttls',
                    label: Text(l10n.tlsModeStarttls,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: 'ssl',
                    label: Text(l10n.tlsModeSsl,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {draft.smtpTlsMode},
                onSelectionChanged: (selection) {
                  draft.smtpTlsMode = selection.first;
                  draft.dirty.add('smtp.tlsMode');
                  onChanged();
                },
              ),
            ],
          ),
        ),
        _buildTestBlock(cs, l10n),
      ],
    );
  }

  Widget _buildTestBlock(ColorScheme cs, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.smtpTestRecipient,
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
                child: TextField(
                  controller: draft.testRecipientCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: testing ? null : onSendTest,
                child: testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.smtpTest),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ─── 邮箱验证策略 ───
class EmailPolicySection extends StatelessWidget {
  final AuthConfigDraft draft;
  final VoidCallback onChanged;

  const EmailPolicySection({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AuthSectionCard(
      title: l10n.emailPolicySection,
      icon: Icons.mark_email_unread_outlined,
      children: [
        AuthSwitchTile(
          title: l10n.emailVerificationRequired,
          subtitle: l10n.emailVerificationRequiredHint,
          value: draft.emailVerificationRequired,
          onChanged: (value) {
            draft.emailVerificationRequired = value;
            draft.dirty.add('emailVerificationRequired');
            onChanged();
          },
        ),
        AuthSwitchTile(
          title: l10n.emailCodeLoginEnabled,
          subtitle: l10n.emailCodeLoginHint,
          value: draft.emailCodeLoginEnabled,
          onChanged: (value) {
            draft.emailCodeLoginEnabled = value;
            draft.dirty.add('emailCodeLoginEnabled');
            onChanged();
          },
        ),
      ],
    );
  }
}

/// ─── TOTP 策略 ───
class TotpPolicySection extends StatelessWidget {
  final AuthConfigDraft draft;
  final VoidCallback onChanged;

  const TotpPolicySection({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AuthSectionCard(
      title: l10n.totpPolicySection,
      icon: Icons.security_rounded,
      children: [
        AuthSwitchTile(
          title: l10n.twoFactorAuth,
          subtitle: l10n.totpSetupDesc,
          value: draft.totpEnabled,
          onChanged: (value) {
            draft.totpEnabled = value;
            draft.dirty.add('totp.enabled');
            onChanged();
          },
        ),
        AuthSwitchTile(
          title: l10n.totpRequiredForAdmins,
          subtitle: l10n.totpRequiredForAdminsHint,
          value: draft.totpRequiredForAdmins,
          onChanged: (value) {
            draft.totpRequiredForAdmins = value;
            draft.dirty.add('totp.requiredForAdmins');
            onChanged();
          },
        ),
        AuthField(
          controller: draft.totpIssuerCtrl,
          label: l10n.totpIssuer,
          hint: l10n.totpIssuerHint,
          onChanged: (_) => draft.dirty.add('totp.issuer'),
        ),
      ],
    );
  }
}
