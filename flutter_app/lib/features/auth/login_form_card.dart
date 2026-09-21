import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/animations.dart';
import 'auth_controls.dart';
import 'auth_widgets.dart';

/// 登录 / 注册表单卡片。
///
/// 只负责渲染三种表单（密码登录、邮箱验证码登录、注册）并把交互回调
/// 交给 [LoginScreen] 的状态机处理。
class LoginFormCard extends StatelessWidget {
  final bool isRegister;
  final String loginMethod;
  final TextEditingController usernameCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController nicknameCtrl;
  final TextEditingController registerEmailCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController codeCtrl;
  final bool obscurePassword;
  final int cooldown;
  final bool sendingCode;
  final VoidCallback onSubmit;
  final VoidCallback onSendCode;
  final VoidCallback onToggleObscure;
  final ValueChanged<String> onMethodChanged;

  const LoginFormCard({
    super.key,
    required this.isRegister,
    required this.loginMethod,
    required this.usernameCtrl,
    required this.passwordCtrl,
    required this.nicknameCtrl,
    required this.registerEmailCtrl,
    required this.emailCtrl,
    required this.codeCtrl,
    required this.obscurePassword,
    required this.cooldown,
    required this.sendingCode,
    required this.onSubmit,
    required this.onSendCode,
    required this.onToggleObscure,
    required this.onMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return SlideAndFade(
      delay: const Duration(milliseconds: 150),
      duration: const Duration(milliseconds: 500),
      child: AuthCard(
        child: Column(
          children: [
            // 登录方式切换（仅登录模式）
            if (!isRegister) ...[
              AuthSegmentedSwitch(
                segments: [
                  AuthSegment('password', l10n.loginWithPassword),
                  AuthSegment('email', l10n.loginWithEmailCode),
                ],
                value: loginMethod,
                onChanged: onMethodChanged,
              ),
              const SizedBox(height: 18),
            ],

            if (isRegister)
              ..._buildRegisterFields(cs, l10n)
            else if (loginMethod == 'email')
              ..._buildEmailCodeFields(l10n)
            else
              ..._buildPasswordFields(cs, l10n),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPasswordFields(ColorScheme cs, AppLocalizations l10n) {
    return [
      LoginTextField(
        controller: usernameCtrl,
        label: l10n.username,
        hint: '请输入用户名',
        icon: Icons.person_outline_rounded,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 14),
      _buildPasswordField(cs, l10n),
    ];
  }

  List<Widget> _buildRegisterFields(ColorScheme cs, AppLocalizations l10n) {
    return [
      LoginTextField(
        controller: usernameCtrl,
        label: l10n.username,
        hint: '请输入用户名',
        icon: Icons.person_outline_rounded,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 14),
      LoginTextField(
        controller: nicknameCtrl,
        label: '昵称（可选）',
        hint: '给自己取个名字',
        icon: Icons.badge_outlined,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 14),
      LoginTextField(
        controller: registerEmailCtrl,
        label: l10n.email,
        hint: l10n.registerEmailHint,
        icon: Icons.alternate_email_rounded,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 14),
      _buildPasswordField(cs, l10n),
    ];
  }

  List<Widget> _buildEmailCodeFields(AppLocalizations l10n) {
    return [
      LoginTextField(
        controller: emailCtrl,
        label: l10n.email,
        hint: 'you@example.com',
        icon: Icons.alternate_email_rounded,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: (cooldown > 0 || sendingCode) ? null : onSendCode,
          icon: const Icon(Icons.send_rounded, size: 16),
          label: Text(
            cooldown > 0 ? '${l10n.resendCode} ($cooldown)' : l10n.sendCode,
          ),
        ),
      ),
      const SizedBox(height: 6),
      LoginTextField(
        controller: codeCtrl,
        label: l10n.emailCode,
        hint: '6 位验证码',
        icon: Icons.pin_outlined,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onSubmit(),
      ),
    ];
  }

  Widget _buildPasswordField(ColorScheme cs, AppLocalizations l10n) {
    return LoginTextField(
      controller: passwordCtrl,
      label: l10n.password,
      hint: '请输入密码',
      icon: Icons.lock_outline_rounded,
      obscureText: obscurePassword,
      onSubmitted: (_) => onSubmit(),
      suffixIcon: GestureDetector(
        onTap: onToggleObscure,
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Icon(
            obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
            color: cs.onSurfaceVariant.withOpacity(0.35),
          ),
        ),
      ),
    );
  }
}
