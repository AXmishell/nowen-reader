import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// 认证 API
class AuthApi {
  final Dio _dio;
  AuthApi(this._dio);

  /// 登录
  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    return res.data;
  }

  /// 注册
  ///
  /// [email] 可选；当管理员开启邮箱验证策略时服务端要求必须提供。
  Future<Map<String, dynamic>> register(
      String username, String password, String nickname,
      {String email = ''}) async {
    final res = await _dio.post('/auth/register', data: {
      'username': username,
      'password': password,
      'nickname': nickname,
      'email': email,
    });
    return res.data;
  }

  /// 退出登录
  Future<void> logout() async {
    await _dio.post('/auth/logout');
  }

  /// 获取当前用户信息
  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get('/auth/me');
    return res.data;
  }

  // ============================================================
  // 邮箱验证 / 验证码登录
  // ============================================================

  /// 发送邮箱验证码。
  ///
  /// [purpose] 为 `verify`（验证邮箱）或 `login`（验证码登录）。
  Future<Map<String, dynamic>> sendEmailCode(
      String email, String purpose) async {
    final res = await _dio.post('/auth/email/send', data: {
      'email': email,
      'purpose': purpose,
    });
    return res.data;
  }

  /// 校验邮箱验证码（验证已绑定的邮箱）。
  Future<Map<String, dynamic>> verifyEmailCode(String email, String code) async {
    final res = await _dio.post('/auth/email/verify', data: {
      'email': email,
      'code': code,
    });
    return res.data;
  }

  /// 使用邮箱验证码登录。
  Future<Map<String, dynamic>> loginWithEmailCode(
      String email, String code) async {
    final res = await _dio.post('/auth/email/login', data: {
      'email': email,
      'code': code,
    });
    return res.data;
  }

  // ============================================================
  // 自助绑定邮箱
  // ============================================================

  /// 为当前登录账户发送邮箱绑定验证码。
  Future<Map<String, dynamic>> sendEmailBindCode(String email) async {
    final res = await _dio.post('/auth/email/bind/send', data: {
      'email': email,
    });
    return res.data;
  }

  /// 校验验证码并完成邮箱绑定。
  Future<Map<String, dynamic>> verifyEmailBind(String email, String code) async {
    final res = await _dio.post('/auth/email/bind/verify', data: {
      'email': email,
      'code': code,
    });
    return res.data;
  }

  // ============================================================
  // TOTP 两步验证
  // ============================================================

  /// 开始 TOTP 绑定，返回 `{secret, otpauthUrl}`。
  Future<Map<String, dynamic>> totpSetup() async {
    final res = await _dio.post('/auth/totp/setup');
    return res.data;
  }

  /// 校验验证码后启用 TOTP，返回一次性恢复码 `{recoveryCodes: [...]}`。
  Future<Map<String, dynamic>> totpEnable(String code) async {
    final res = await _dio.post('/auth/totp/enable', data: {'code': code});
    return res.data;
  }

  /// 关闭 TOTP（接受 TOTP 验证码或恢复码）。
  Future<Map<String, dynamic>> totpDisable(String code) async {
    final res = await _dio.post('/auth/totp/disable', data: {'code': code});
    return res.data;
  }

  /// 查询当前账户的 TOTP 启用状态，返回 `{enabled: bool}`。
  Future<Map<String, dynamic>> totpStatus() async {
    final res = await _dio.get('/auth/totp/status');
    return res.data;
  }

  /// 完成登录 TOTP 二次验证，成功时返回 `{user: {...}}` 并设置会话 Cookie。
  Future<Map<String, dynamic>> totpVerify(
      String challengeId, String code) async {
    final res = await _dio.post('/auth/totp/verify', data: {
      'challengeId': challengeId,
      'code': code,
    });
    return res.data;
  }

  // ============================================================
  // OIDC 身份管理
  // ============================================================

  /// 获取可用的 OIDC 登录提供方（已解出 `providers` 数组）。
  Future<List<Map<String, dynamic>>> oidcProviders() async {
    final res = await _dio.get('/auth/oidc/providers');
    final data = res.data;
    if (data is Map) {
      final providers = data['providers'];
      if (providers is List) {
        return providers
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return const [];
  }

  /// 获取当前账户已关联的 OIDC 身份列表。
  Future<List<Map<String, dynamic>>> oidcIdentities() async {
    final res = await _dio.get('/auth/oidc/identities');
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }

  /// 解绑指定 OIDC 身份。
  Future<void> unlinkOidcIdentity(String id) async {
    await _dio.delete('/auth/oidc/identities/$id');
  }

  // ============================================================
  // 管理员：认证与安全配置（SMTP / 邮箱策略 / TOTP / OIDC）
  // ============================================================

  /// 获取认证配置。
  ///
  /// 服务端不会回显任何密钥，仅通过 `passwordSet` / `clientSecretSet`
  /// 标记是否已保存密钥。
  Future<Map<String, dynamic>> getAuthConfig() async {
    final res = await _dio.get('/admin/auth-config');
    return res.data;
  }

  /// 更新认证配置（指针式局部更新，仅提交被修改的字段）。
  Future<void> updateAuthConfig(Map<String, dynamic> body) async {
    await _dio.put('/admin/auth-config', data: body);
  }

  /// 使用当前 SMTP 配置发送一封测试邮件。
  Future<void> sendSmtpTest(String to) async {
    await _dio.post('/admin/auth-config/smtp-test', data: {'to': to});
  }
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});
