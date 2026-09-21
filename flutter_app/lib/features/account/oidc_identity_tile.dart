import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 单条已关联的 OIDC 身份：展示邮箱 / 提供方 / 用户标识，并提供解绑入口。
class OidcIdentityTile extends StatelessWidget {
  final Map<String, dynamic> identity;
  final bool busy;
  final VoidCallback onUnlink;

  const OidcIdentityTile({
    super.key,
    required this.identity,
    required this.busy,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final email = identity['email']?.toString() ?? '';
    final subject = identity['subject']?.toString() ?? '';
    final issuer = identity['issuer']?.toString() ?? '';
    final title = email.isNotEmpty ? email : subject;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.identityIssuer}: $issuer',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
                if (email.isNotEmpty && subject.isNotEmpty)
                  Text(
                    '${l10n.identitySubject}: $subject',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: busy ? null : onUnlink,
            child: Text(
              l10n.unlink,
              style: TextStyle(fontSize: 12, color: cs.error),
            ),
          ),
        ],
      ),
    );
  }
}
