import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_error.dart';
import '../../data/api/auth_api.dart';
import '../../data/providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import '../auth/oidc_result.dart';
import '../auth/oidc_webview_screen.dart';
import 'oidc_identity_tile.dart';
import 'security_widgets.dart';

/// OIDC 关联账户区块：列出已关联身份，支持绑定 / 解绑。
///
/// 仅在服务端启用了 OIDC（`oidcProviders` 非空）时提供操作，否则展示提示。
class OidcSection extends ConsumerStatefulWidget {
  const OidcSection({super.key});

  @override
  ConsumerState<OidcSection> createState() => _OidcSectionState();
}

class _OidcSectionState extends ConsumerState<OidcSection> {
  bool _loading = true;
  bool _busy = false;
  bool _available = false;
  List<Map<String, dynamic>> _identities = const [];
  String? _message;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // 登录页通常已拉取过，这里兜底保证进入本页也能拿到提供方列表。
      if (ref.read(authProvider).oidcProviders.isEmpty) {
        await ref.read(authProvider.notifier).refreshOidcProviders();
      }
      final available = ref.read(authProvider).oidcProviders.isNotEmpty;
      final identities =
          available ? await _fetchIdentities() : const <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _loading = false;
        _available = available;
        _identities = identities;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = apiErrorMessage(e);
        _isError = true;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchIdentities() {
    return ref.read(authApiProvider).oidcIdentities();
  }

  Future<void> _link() async {
    final l10n = AppLocalizations.of(context);
    final result = await Navigator.of(context).push<OidcWebViewResult>(
      MaterialPageRoute(
        builder: (_) => const OidcWebViewScreen(mode: OidcWebViewMode.link),
      ),
    );
    if (!mounted || result == null) return;

    if (result.status == OidcWebViewStatus.error) {
      setState(() {
        _message = oidcErrorText(l10n, result.errorCode);
        _isError = true;
      });
      return;
    }

    // `session` / `totp` 均表示身份已写入：`totp` 只说明服务端未续签新会话，
    // 当前登录会话依然有效。这里同步一次用户信息与身份列表。
    await ref.read(authProvider.notifier).refreshUser();
    try {
      final identities = await _fetchIdentities();
      if (!mounted) return;
      setState(() {
        _identities = identities;
        _message = l10n.linkSuccess;
        _isError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = apiErrorMessage(e);
        _isError = true;
      });
    }
  }

  Future<void> _unlink(Map<String, dynamic> identity) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.unlink),
        content: Text(l10n.unlinkConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final id = identity['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(authApiProvider).unlinkOidcIdentity(id);
      final identities = await _fetchIdentities();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _identities = identities;
        _message = l10n.unlinkSuccess;
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return SecuritySection(
      title: l10n.linkedAccounts,
      icon: Icons.link_rounded,
      trailing: _loading
          ? null
          : SecurityBadge(
              text: '${_identities.length}',
              ok: _identities.isNotEmpty,
            ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (!_available)
                Text(
                  l10n.oidcNotEnabled,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: cs.onSurfaceVariant,
                  ),
                )
              else ...[
                if (_identities.isEmpty)
                  Text(
                    l10n.noLinkedAccounts,
                    style: TextStyle(fontSize: 13, color: cs.onSurface),
                  )
                else
                  for (final identity in _identities)
                    OidcIdentityTile(
                      identity: identity,
                      busy: _busy,
                      onUnlink: () => _unlink(identity),
                    ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _link,
                  icon: const Icon(Icons.add_link_rounded, size: 18),
                  label: Text(l10n.linkAccount),
                ),
              ],
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
}
