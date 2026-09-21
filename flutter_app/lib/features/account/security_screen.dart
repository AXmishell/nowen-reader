import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/animations.dart';
import 'email_section.dart';
import 'oidc_section.dart';
import 'totp_section.dart';

/// 账户安全页面 — 所有登录用户可见。
///
/// 包含邮箱绑定 / 验证、两步验证（TOTP）与 OIDC 关联账户三个区块。
class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountSecurity)),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SlideAndFade(
                  delay: const Duration(milliseconds: 100),
                  child: const EmailSection(),
                ),
                const SizedBox(height: 16),
                SlideAndFade(
                  delay: const Duration(milliseconds: 200),
                  child: const TotpSection(),
                ),
                const SizedBox(height: 16),
                SlideAndFade(
                  delay: const Duration(milliseconds: 300),
                  child: const OidcSection(),
                ),
              ],
            ),
    );
  }
}
