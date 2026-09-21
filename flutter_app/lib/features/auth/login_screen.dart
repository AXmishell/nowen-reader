import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/api_error.dart';
import '../../data/api/auth_api.dart';
import '../../data/providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import 'auth_controls.dart';
import 'login_form_card.dart';
import 'login_header.dart';
import 'oidc_login_buttons.dart';
import 'oidc_result.dart';
import 'oidc_webview_screen.dart';
import 'totp_step.dart';

/// 登录 & 注册页面 — 极简优雅风格
///
/// 状态机：密码登录 / 邮箱验证码登录 / 注册 → （可选）TOTP 二次验证 → 首页。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _registerEmailCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _isRegister = false;
  bool _obscurePassword = true;

  /// 登录方式：`password`（密码登录）或 `email`（邮箱验证码登录）。
  String _loginMethod = 'password';

  /// 非空时进入 TOTP 二次验证步骤。
  String? _totpChallengeId;
  bool _totpMustSetup = false;

  /// OIDC WebView 流程失败时的错误文案（与 `authState.error` 相互独立）。
  String? _oidcError;

  /// 邮箱验证码发送冷却（秒）。
  int _cooldown = 0;
  Timer? _cooldownTimer;
  bool _sendingCode = false;

  AnimationController? _bgAnimCtrl;
  Animation<double>? _bgAnimation;

  @override
  void initState() {
    super.initState();
    _bgAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _bgAnimation = CurvedAnimation(parent: _bgAnimCtrl!, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(authProvider);
      if (state.needsSetup) {
        setState(() => _isRegister = true);
      }
      // 拉取可用的 OIDC 提供方；失败时内部静默清空，不影响普通登录。
      ref.read(authProvider.notifier).refreshOidcProviders();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _bgAnimCtrl?.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    _registerEmailCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════
  // ─── 提交逻辑 ───
  // ═══════════════════════════════════════════════

  Future<void> _submit() async {
    if (_isRegister) return _submitRegister();
    if (_loginMethod == 'email') return _submitEmailCode();
    return _submitPassword();
  }

  Future<void> _submitPassword() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (username.isEmpty || password.isEmpty) return;

    HapticFeedback.lightImpact();
    ref.read(authProvider.notifier).clearError();
    final outcome = await ref
        .read(authProvider.notifier)
        .loginWithOutcome(username, password);
    _handleOutcome(outcome);
  }

  Future<void> _submitEmailCode() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (email.isEmpty || code.isEmpty) return;

    HapticFeedback.lightImpact();
    ref.read(authProvider.notifier).clearError();
    final outcome = await ref
        .read(authProvider.notifier)
        .loginWithEmailCode(email, code);
    _handleOutcome(outcome);
  }

  Future<void> _submitRegister() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final nickname = _nicknameCtrl.text.trim();
    final email = _registerEmailCtrl.text.trim();
    if (username.isEmpty || password.isEmpty) return;

    HapticFeedback.lightImpact();
    ref.read(authProvider.notifier).clearError();
    final ok = await ref.read(authProvider.notifier).register(
          username,
          password,
          nickname,
          email: email,
        );
    if (ok && mounted) context.go('/');
  }

  /// 处理第一因子登录结果：会话 → 首页；需要二次验证 → TOTP 步骤。
  ///
  /// 失败时错误已写入 `authState.error`，由错误横幅展示。
  void _handleOutcome(LoginOutcome outcome) {
    if (!mounted) return;
    if (outcome.isSession) {
      context.go('/');
    } else if (outcome.isTotpRequired) {
      setState(() {
        _totpChallengeId = outcome.challengeId;
        _totpMustSetup = outcome.mustSetupTotp;
      });
    }
  }

  /// 打开应用内 WebView 完成 OIDC 登录。
  ///
  /// 返回结果分三种：已建立会话 → 刷新用户并进入首页；需要 TOTP → 复用既有
  /// 两步验证步骤；失败 → 展示映射后的错误文案。用户中途返回（null）不处理。
  Future<void> _startOidcLogin() async {
    HapticFeedback.lightImpact();
    setState(() => _oidcError = null);
    final l10n = AppLocalizations.of(context);
    final result = await Navigator.of(context).push<OidcWebViewResult>(
      MaterialPageRoute(
        builder: (_) => const OidcWebViewScreen(mode: OidcWebViewMode.login),
      ),
    );
    if (!mounted || result == null) return;

    switch (result.status) {
      case OidcWebViewStatus.session:
        await ref.read(authProvider.notifier).refreshUser();
        if (mounted) context.go('/');
        break;
      case OidcWebViewStatus.totp:
        setState(() {
          _totpChallengeId = result.challengeId;
          _totpMustSetup = false;
        });
        break;
      case OidcWebViewStatus.error:
        setState(() => _oidcError = oidcErrorText(l10n, result.errorCode));
        break;
    }
  }

  /// 发送邮箱验证码（登录用途），成功后进入 60 秒冷却。
  Future<void> _sendLoginCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || _cooldown > 0 || _sendingCode) return;

    final l10n = AppLocalizations.of(context);
    setState(() => _sendingCode = true);
    try {
      await ref.read(authApiProvider).sendEmailCode(email, 'login');
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.codeSent)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.operationFailed}: ${apiErrorMessage(e)}')),
      );
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _cooldown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldown = 0);
        return;
      }
      setState(() => _cooldown -= 1);
    });
  }

  void _toggleMode() {
    HapticFeedback.selectionClick();
    setState(() {
      _isRegister = !_isRegister;
      _oidcError = null;
      ref.read(authProvider.notifier).clearError();
    });
  }

  void _changeMethod(String value) {
    HapticFeedback.selectionClick();
    ref.read(authProvider.notifier).clearError();
    setState(() {
      _loginMethod = value;
      _oidcError = null;
    });
  }

  void _backToLogin() {
    ref.read(authProvider.notifier).clearError();
    setState(() {
      _totpChallengeId = null;
      _totpMustSetup = false;
    });
  }

  // ═══════════════════════════════════════════════
  // ─── 构建 ───
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final inTotpStep = _totpChallengeId != null;

    return Scaffold(
      body: _bgAnimation == null
          ? const SizedBox.shrink()
          : AnimatedBuilder(
              animation: _bgAnimation!,
              builder: (context, child) {
                final animValue = _bgAnimation?.value ?? 0.0;
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [
                              Color.lerp(const Color(0xFF0F0F0F),
                                  cs.primary.withOpacity(0.15), animValue)!,
                              const Color(0xFF0F0F0F),
                            ]
                          : [
                              Color.lerp(const Color(0xFFFAFAF9),
                                  cs.primary.withOpacity(0.06), animValue)!,
                              const Color(0xFFFAFAF9),
                            ],
                      stops: const [0.0, 0.45],
                    ),
                  ),
                  child: child,
                );
              },
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 48),
                        LoginLogoSection(
                          needsSetup: authState.needsSetup,
                          isRegister: _isRegister,
                        ),
                        const SizedBox(height: 44),

                        if (inTotpStep)
                          TotpStepView(
                            challengeId: _totpChallengeId!,
                            mustSetupTotp: _totpMustSetup,
                            onSuccess: () => context.go('/'),
                            onBack: _backToLogin,
                          )
                        else ...[
                          LoginFormCard(
                            isRegister: _isRegister,
                            loginMethod: _loginMethod,
                            usernameCtrl: _usernameCtrl,
                            passwordCtrl: _passwordCtrl,
                            nicknameCtrl: _nicknameCtrl,
                            registerEmailCtrl: _registerEmailCtrl,
                            emailCtrl: _emailCtrl,
                            codeCtrl: _codeCtrl,
                            obscurePassword: _obscurePassword,
                            cooldown: _cooldown,
                            sendingCode: _sendingCode,
                            onSubmit: _submit,
                            onSendCode: _sendLoginCode,
                            onToggleObscure: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            onMethodChanged: _changeMethod,
                          ),

                          if (authState.error != null) ...[
                            const SizedBox(height: 12),
                            LoginErrorBanner(error: authState.error!),
                          ],

                          const SizedBox(height: 24),
                          _buildSubmitButton(authState, l10n),

                          // SSO：仅当服务端启用了 OIDC 且非首次安装引导时展示。
                          if (!authState.needsSetup &&
                              authState.oidcProviders.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            OidcLoginButtons(
                              providers: authState.oidcProviders,
                              enabled: !authState.isLoading,
                              onPressed: _startOidcLogin,
                            ),
                          ],

                          if (_oidcError != null) ...[
                            const SizedBox(height: 12),
                            LoginErrorBanner(error: _oidcError!),
                          ],

                          const SizedBox(height: 20),
                          if (!authState.needsSetup)
                            LoginToggleLink(
                              isRegister: _isRegister,
                              onTap: _toggleMode,
                            ),
                        ],

                        const SizedBox(height: 12),
                        const LoginServerLink(),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSubmitButton(AuthState authState, AppLocalizations l10n) {
    final String label;
    final IconData icon;
    if (_isRegister) {
      label = l10n.register;
      icon = Icons.person_add_rounded;
    } else if (_loginMethod == 'email') {
      label = l10n.codeLogin;
      icon = Icons.mark_email_read_rounded;
    } else {
      label = l10n.login;
      icon = Icons.login_rounded;
    }

    return LoginSubmitButton(
      label: label,
      icon: icon,
      loading: authState.isLoading,
      onTap: _submit,
    );
  }
}
