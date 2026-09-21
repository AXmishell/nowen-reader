import 'package:flutter/material.dart';

import '../../widgets/animations.dart';

/// ─── 登录方式切换项 ───
class AuthSegment {
  final String value;
  final String label;
  const AuthSegment(this.value, this.label);
}

/// ─── 登录方式分段切换（密码 / 邮箱验证码）───
class AuthSegmentedSwitch extends StatelessWidget {
  final List<AuthSegment> segments;
  final String value;
  final ValueChanged<String> onChanged;

  const AuthSegmentedSwitch({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: GestureDetector(
                onTap: segment.value == value
                    ? null
                    : () => onChanged(segment.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: segment.value == value
                        ? (isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: segment.value == value && !isDark
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      segment.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: segment.value == value
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: segment.value == value
                            ? cs.primary
                            : cs.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ─── 登录错误横幅 ───
class LoginErrorBanner extends StatelessWidget {
  final String error;
  const LoginErrorBanner({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SlideAndFade(
      duration: const Duration(milliseconds: 300),
      beginOffset: const Offset(0, -0.1),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.errorContainer.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.error.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: cs.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Icon(Icons.warning_amber_rounded, size: 16, color: cs.error),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: TextStyle(color: cs.error, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── 登录主按钮 ───
class LoginSubmitButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  const LoginSubmitButton({
    super.key,
    required this.label,
    required this.icon,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SlideAndFade(
      delay: const Duration(milliseconds: 300),
      duration: const Duration(milliseconds: 500),
      child: PressableScale(
        onTap: loading ? null : onTap,
        scaleDown: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: loading
                  ? [cs.primary.withOpacity(0.5), cs.primary.withOpacity(0.35)]
                  : [cs.primary, cs.primary.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: loading
                ? []
                : [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: loading
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '请稍候…',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
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
