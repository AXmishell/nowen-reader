import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/animations.dart';

/// ─── 登录页品牌区（Logo + 标题）───
class LoginLogoSection extends StatelessWidget {
  final bool needsSetup;
  final bool isRegister;

  const LoginLogoSection({
    super.key,
    required this.needsSetup,
    required this.isRegister,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SlideAndFade(
      duration: const Duration(milliseconds: 600),
      child: Column(
        children: [
          BreathingPulse(
            minScale: 0.96,
            maxScale: 1.04,
            duration: const Duration(milliseconds: 2800),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primary,
                    cs.primary.withOpacity(0.65),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.2),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            needsSetup
                ? '创建管理员'
                : (isRegister ? '创建账户' : '欢迎回来'),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            needsSetup
                ? '首次使用，请创建管理员账户'
                : (isRegister ? '注册一个新账户开始阅读' : '登录以继续你的阅读之旅'),
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant.withOpacity(0.55),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── 切换登录 / 注册 ───
class LoginToggleLink extends StatelessWidget {
  final bool isRegister;
  final VoidCallback onTap;

  const LoginToggleLink({
    super.key,
    required this.isRegister,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SlideAndFade(
      delay: const Duration(milliseconds: 400),
      duration: const Duration(milliseconds: 400),
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text.rich(
            TextSpan(
              text: isRegister ? '已有账户？ ' : '没有账户？ ',
              style: TextStyle(
                color: cs.onSurfaceVariant.withOpacity(0.5),
                fontSize: 14,
              ),
              children: [
                TextSpan(
                  text: isRegister ? '去登录' : '去注册',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ─── 切换服务器入口 ───
class LoginServerLink extends StatelessWidget {
  const LoginServerLink({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return SlideAndFade(
      delay: const Duration(milliseconds: 450),
      duration: const Duration(milliseconds: 400),
      child: GestureDetector(
        onTap: () => context.go('/server'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 16,
                color: cs.onSurfaceVariant.withOpacity(0.35),
              ),
              const SizedBox(width: 6),
              Text(
                l10n.switchServer,
                style: TextStyle(
                  color: cs.onSurfaceVariant.withOpacity(0.4),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
