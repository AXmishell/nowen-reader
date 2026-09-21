import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../models/comic.dart';

enum ServerConnectionStatus {
  unknown,
  checking,
  online,
  offline,
  unauthorized,
}

/// 登录结果类型。
enum LoginOutcomeKind {
  /// 已建立会话（直接登录成功，或 TOTP 校验通过）。
  session,

  /// 需要 TOTP 两步验证，需携带 [LoginOutcome.challengeId] 调用 verifyTotp。
  totpRequired,

  /// 登录失败，具体错误见 [AuthState.error]。
  failed,
}

/// 登录结果：区分「会话已建立」「需要 TOTP 二次验证」「失败」三种情况。
class LoginOutcome {
  final LoginOutcomeKind kind;

  /// 需要二次验证时由服务端下发的挑战 ID。
  final String? challengeId;

  /// 服务端建议（非强制）尽快为管理员开启 TOTP。
  final bool mustSetupTotp;

  const LoginOutcome._({
    required this.kind,
    this.challengeId,
    this.mustSetupTotp = false,
  });

  /// 登录成功，会话已建立。
  const LoginOutcome.session({bool mustSetupTotp = false})
      : this._(kind: LoginOutcomeKind.session, mustSetupTotp: mustSetupTotp);

  /// 需要 TOTP 二次验证。
  const LoginOutcome.totpRequired(String challengeId,
      {bool mustSetupTotp = false})
      : this._(
          kind: LoginOutcomeKind.totpRequired,
          challengeId: challengeId,
          mustSetupTotp: mustSetupTotp,
        );

  /// 登录失败。
  const LoginOutcome.failed() : this._(kind: LoginOutcomeKind.failed);

  bool get isSession => kind == LoginOutcomeKind.session;
  bool get isTotpRequired => kind == LoginOutcomeKind.totpRequired;
  bool get isFailed => kind == LoginOutcomeKind.failed;
}

/// 认证状态
class AuthState {
  final AuthUser? user;
  final String serverUrl;
  final bool isLoading;
  final bool needsSetup;
  final String? error;
  final String registrationMode;
  final ServerConnectionStatus connectionStatus;

  /// 最近一次登录响应中的 `mustSetupTotp`（管理员 TOTP 引导提示）。
  final bool mustSetupTotp;

  /// 可用的 OIDC 登录提供方列表，由 [AuthNotifier.refreshOidcProviders] 填充。
  final List<Map<String, dynamic>> oidcProviders;

  const AuthState({
    this.user,
    this.serverUrl = '',
    this.isLoading = true,
    this.needsSetup = false,
    this.error,
    this.registrationMode = 'open',
    this.connectionStatus = ServerConnectionStatus.unknown,
    this.mustSetupTotp = false,
    this.oidcProviders = const [],
  });

  bool get isOffline => connectionStatus == ServerConnectionStatus.offline;
  bool get isOnline => connectionStatus == ServerConnectionStatus.online;

  AuthState copyWith({
    AuthUser? user,
    String? serverUrl,
    bool? isLoading,
    bool? needsSetup,
    String? error,
    String? registrationMode,
    ServerConnectionStatus? connectionStatus,
    bool? mustSetupTotp,
    List<Map<String, dynamic>>? oidcProviders,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      serverUrl: serverUrl ?? this.serverUrl,
      isLoading: isLoading ?? this.isLoading,
      needsSetup: needsSetup ?? this.needsSetup,
      error: clearError ? null : (error ?? this.error),
      registrationMode: registrationMode ?? this.registrationMode,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      mustSetupTotp: mustSetupTotp ?? this.mustSetupTotp,
      oidcProviders: oidcProviders ?? this.oidcProviders,
    );
  }
}

/// 认证状态管理 Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final url = await loadServerUrl();
    if (url.isEmpty) {
      state = state.copyWith(
        serverUrl: '',
        isLoading: false,
        connectionStatus: ServerConnectionStatus.unknown,
      );
      return;
    }

    state = state.copyWith(
      serverUrl: url,
      isLoading: true,
      connectionStatus: ServerConnectionStatus.checking,
    );
    _ref.read(serverUrlProvider.notifier).state = url;
    await checkAuth();
  }

  /// 设置服务器地址。
  ///
  /// 地址格式已经由页面校验，因此先持久化，再检测连通性。即使当前断网，
  /// 用户下次打开 App 时也不会丢失刚输入的服务器地址。
  Future<bool> setServerUrl(String url) async {
    await saveServerUrl(url);
    state = state.copyWith(
      serverUrl: url,
      isLoading: true,
      connectionStatus: ServerConnectionStatus.checking,
      clearError: true,
    );
    _ref.read(serverUrlProvider.notifier).state = url;

    final ok = await testServerConnection(url);
    if (!ok) {
      state = state.copyWith(
        isLoading: false,
        connectionStatus: ServerConnectionStatus.offline,
        error: '服务器暂时不可达，地址已保存，可进入离线缓存',
      );
      return false;
    }

    await checkAuth();
    return state.connectionStatus != ServerConnectionStatus.offline;
  }

  /// 检查当前认证状态。
  ///
  /// 只有服务端明确返回 401/403 才视为认证失效；超时、断网、DNS 和
  /// 服务器临时不可达都进入离线状态，不清除 Cookie，也不清除已有用户。
  Future<void> checkAuth() async {
    if (state.serverUrl.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        connectionStatus: ServerConnectionStatus.unknown,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      connectionStatus: ServerConnectionStatus.checking,
      clearError: true,
    );

    try {
      final api = _ref.read(authApiProvider);
      final data = await api.me();
      final needsSetup = data['needsSetup'] == true;
      final registrationMode = data['registrationMode'] ?? 'open';
      final userData = data['user'];
      AuthUser? user;
      if (userData != null) {
        user = AuthUser.fromJson(userData);
      }

      state = state.copyWith(
        user: user,
        isLoading: false,
        needsSetup: needsSetup,
        registrationMode: registrationMode.toString(),
        connectionStatus: ServerConnectionStatus.online,
        clearUser: userData == null,
        clearError: true,
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        state = state.copyWith(
          isLoading: false,
          connectionStatus: ServerConnectionStatus.unauthorized,
          clearUser: true,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          connectionStatus: ServerConnectionStatus.offline,
          error: '服务器暂时不可达，已切换到离线模式',
        );
      }
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        connectionStatus: ServerConnectionStatus.offline,
        error: '服务器暂时不可达，已切换到离线模式',
      );
    }
  }

  /// 重新拉取当前用户信息（邮箱绑定 / TOTP 状态变更后调用）。
  ///
  /// 只更新用户对象，不触碰加载态与连接状态；失败时静默忽略，避免账户
  /// 安全页面的局部操作把整个应用误判为离线。
  Future<void> refreshUser() async {
    if (state.serverUrl.isEmpty) return;
    try {
      final data = await _ref.read(authApiProvider).me();
      final userData = data['user'];
      if (userData != null) {
        state = state.copyWith(user: AuthUser.fromJson(userData));
      }
    } catch (e) {
      print('[AUTH] Failed to refresh user: $e');
    }
  }

  /// 登录（兼容旧调用）。
  ///
  /// 返回是否直接建立会话；若账户启用了 TOTP，服务端会返回挑战而不会建立
  /// 会话，此时返回 false。需要挑战 ID 的调用方请改用 [loginWithOutcome]。
  Future<bool> login(String username, String password) async {
    final outcome = await loginWithOutcome(username, password);
    return outcome.isSession;
  }

  /// 密码登录，支持 TOTP 二次验证。
  ///
  /// 返回值区分「会话已建立」「需要 TOTP」「登录失败」三种情况，便于调用方
  /// 根据 [LoginOutcome.kind] 决定跳转主页还是展示 TOTP 输入。
  Future<LoginOutcome> loginWithOutcome(
      String username, String password) async {
    return _runFirstFactorLogin(
      () => _ref.read(authApiProvider).login(username, password),
    );
  }

  /// 邮箱验证码登录，同样支持 TOTP 二次验证。
  Future<LoginOutcome> loginWithEmailCode(String email, String code) async {
    return _runFirstFactorLogin(
      () => _ref.read(authApiProvider).loginWithEmailCode(email, code),
    );
  }

  /// 第一因子登录的共享流程。
  ///
  /// `/auth/login` 与 `/auth/email/login` 的响应结构一致：
  /// `{user: {...}}` 表示会话已建立，`{totpRequired, challengeId}` 表示需要
  /// 二次验证，二者都可能附带 `mustSetupTotp`。
  Future<LoginOutcome> _runFirstFactorLogin(
      Future<Map<String, dynamic>> Function() request) async {
    state = state.copyWith(
      isLoading: true,
      connectionStatus: ServerConnectionStatus.checking,
      clearError: true,
    );
    try {
      final client = _ref.read(apiClientProvider);
      await client.clearCookies();

      final data = await request();

      final mustSetupTotp = data['mustSetupTotp'] == true;
      final totpRequired = data['totpRequired'] == true;
      final challengeId = data['challengeId']?.toString() ?? '';

      if (totpRequired && challengeId.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          connectionStatus: ServerConnectionStatus.online,
          mustSetupTotp: mustSetupTotp,
          clearError: true,
        );
        return LoginOutcome.totpRequired(challengeId,
            mustSetupTotp: mustSetupTotp);
      }

      final userData = data['user'];
      if (userData != null) {
        final user = AuthUser.fromJson(userData);

        final uri = Uri.parse('${client.baseUrl}/api');
        final cookies = await persistCookieJar.loadForRequest(uri);
        print(
          '[AUTH] After login, cookies for $uri: '
          '${cookies.map((c) => '${c.name}=${c.value.substring(0, c.value.length.clamp(0, 8))}...').toList()}',
        );

        state = state.copyWith(
          user: user,
          isLoading: false,
          connectionStatus: ServerConnectionStatus.online,
          mustSetupTotp: mustSetupTotp,
          clearError: true,
        );
        await saveServerRecord(ServerRecord(
          url: state.serverUrl,
          username: user.username,
          nickname: user.nickname.isNotEmpty ? user.nickname : null,
          lastUsed: DateTime.now(),
        ));
        return LoginOutcome.session(mustSetupTotp: mustSetupTotp);
      }

      state = state.copyWith(
        isLoading: false,
        connectionStatus: ServerConnectionStatus.online,
        error: '登录失败',
        mustSetupTotp: false,
      );
      return const LoginOutcome.failed();
    } catch (e) {
      String msg = '登录失败';
      var status = ServerConnectionStatus.online;
      if (e is DioException) {
        if (e.response?.data is Map) {
          msg = (e.response!.data as Map)['error'] ?? msg;
        }
        if (e.response == null) {
          status = ServerConnectionStatus.offline;
          msg = '无法连接到服务器，请检查网络';
        }
      }
      state = state.copyWith(
        isLoading: false,
        connectionStatus: status,
        error: msg,
      );
      return const LoginOutcome.failed();
    }
  }

  /// 完成 TOTP 二次验证。
  ///
  /// 成功后与 [login] 一致地保存用户、记录服务器历史（会话 Cookie 由
  /// CookieManager 自动写入）。
  Future<bool> verifyTotp(String challengeId, String code) async {
    state = state.copyWith(
      isLoading: true,
      connectionStatus: ServerConnectionStatus.checking,
      clearError: true,
    );
    try {
      final api = _ref.read(authApiProvider);
      final data = await api.totpVerify(challengeId, code);
      final userData = data['user'];
      if (userData != null) {
        final user = AuthUser.fromJson(userData);
        state = state.copyWith(
          user: user,
          isLoading: false,
          connectionStatus: ServerConnectionStatus.online,
          mustSetupTotp: false,
          clearError: true,
        );
        await saveServerRecord(ServerRecord(
          url: state.serverUrl,
          username: user.username,
          nickname: user.nickname.isNotEmpty ? user.nickname : null,
          lastUsed: DateTime.now(),
        ));
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        connectionStatus: ServerConnectionStatus.online,
        error: '验证码校验失败',
      );
      return false;
    } catch (e) {
      String msg = '验证码校验失败';
      var status = ServerConnectionStatus.online;
      if (e is DioException) {
        if (e.response?.data is Map) {
          msg = (e.response!.data as Map)['error'] ?? msg;
        }
        if (e.response == null) {
          status = ServerConnectionStatus.offline;
          msg = '无法连接到服务器，请检查网络';
        }
      }
      state = state.copyWith(
        isLoading: false,
        connectionStatus: status,
        error: msg,
      );
      return false;
    }
  }

  /// 刷新可用的 OIDC 登录提供方列表。
  ///
  /// 该接口在登录页展示 SSO 按钮前调用；失败时不阻塞 UI，仅清空列表并记录日志。
  Future<void> refreshOidcProviders() async {
    try {
      final api = _ref.read(authApiProvider);
      final providers = await api.oidcProviders();
      state = state.copyWith(oidcProviders: providers);
    } catch (e) {
      print('[AUTH] Failed to load OIDC providers: $e');
      state = state.copyWith(oidcProviders: const []);
    }
  }

  /// 注册
  ///
  /// [email] 可选；当管理员开启邮箱验证策略时服务端要求必须提供。
  Future<bool> register(String username, String password, String nickname,
      {String email = ''}) async {
    state = state.copyWith(
      isLoading: true,
      connectionStatus: ServerConnectionStatus.checking,
      clearError: true,
    );
    try {
      final api = _ref.read(authApiProvider);
      final data =
          await api.register(username, password, nickname, email: email);
      final userData = data['user'];
      if (userData != null) {
        state = state.copyWith(
          user: AuthUser.fromJson(userData),
          isLoading: false,
          needsSetup: false,
          connectionStatus: ServerConnectionStatus.online,
          clearError: true,
        );
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        connectionStatus: ServerConnectionStatus.online,
        error: '注册失败',
      );
      return false;
    } catch (e) {
      String msg = '注册失败';
      var status = ServerConnectionStatus.online;
      if (e is DioException) {
        if (e.response?.data is Map) {
          msg = (e.response!.data as Map)['error'] ?? msg;
        }
        if (e.response == null) {
          status = ServerConnectionStatus.offline;
          msg = '无法连接到服务器，请检查网络';
        }
      }
      state = state.copyWith(
        isLoading: false,
        connectionStatus: status,
        error: msg,
      );
      return false;
    }
  }

  /// 退出登录
  Future<void> logout() async {
    try {
      final api = _ref.read(authApiProvider);
      await api.logout();
    } catch (_) {}
    state = state.copyWith(clearUser: true, isLoading: false);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
