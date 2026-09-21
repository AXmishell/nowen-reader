import 'package:flutter/material.dart';

/// 应用国际化支持
/// 基于轻量级自定义方案，不依赖额外的 l10n 包
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('zh'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('zh'), // 简体中文
    Locale('en'), // English
  ];

  /// 获取当前语言的翻译表
  Map<String, String> get _localizedStrings {
    switch (locale.languageCode) {
      case 'en':
        return _enStrings;
      case 'zh':
      default:
        return _zhStrings;
    }
  }

  /// 获取翻译文本，找不到时返回 key
  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }

  // ============================================================
  // 通用
  // ============================================================
  String get appTitle => translate('app_title');
  String get cancel => translate('cancel');
  String get confirm => translate('confirm');
  String get save => translate('save');
  String get delete => translate('delete');
  String get edit => translate('edit');
  String get create => translate('create');
  String get refresh => translate('refresh');
  String get search => translate('search');
  String get close => translate('close');
  String get loading => translate('loading');
  String get noData => translate('no_data');
  String get error => translate('error');
  String get retry => translate('retry');
  String get selectAll => translate('select_all');
  String get batchDelete => translate('batch_delete');

  // ============================================================
  // 导航
  // ============================================================
  String get navHome => translate('nav_home');
  String get navSearch => translate('nav_search');
  String get navStats => translate('nav_stats');
  String get navSettings => translate('nav_settings');

  // ============================================================
  // 首页
  // ============================================================
  String get sortAddedAt => translate('sort_added_at');
  String get sortTitle => translate('sort_title');
  String get sortLastRead => translate('sort_last_read');
  String get sortRating => translate('sort_rating');
  String get sortPageCount => translate('sort_page_count');
  String get filterAll => translate('filter_all');
  String get filterComic => translate('filter_comic');
  String get filterNovel => translate('filter_novel');
  String get filterFavorites => translate('filter_favorites');
  String get noContent => translate('no_content');

  // ============================================================
  // 设置
  // ============================================================
  String get settings => translate('settings');
  String get account => translate('account');
  String get admin => translate('admin');
  String get user => translate('user');
  String get serverAddress => translate('server_address');
  String get serverInfo => translate('server_info');
  String get about => translate('about');
  String get version => translate('version');
  String get dataManagement => translate('data_management');
  String get batchScrapeMetadata => translate('batch_scrape_metadata');
  String get batchScrapeDesc => translate('batch_scrape_desc');
  String get logout => translate('logout');
  String get logoutConfirm => translate('logout_confirm');
  String get switchServer => translate('switch_server');
  String get tagManager => translate('tag_manager');
  String get favorites => translate('favorites');

  // ============================================================
  // 标签管理
  // ============================================================
  String get tagManagerTitle => translate('tag_manager_title');
  String get tags => translate('tags');
  String get categories => translate('categories');
  String get searchTags => translate('search_tags');
  String get searchCategories => translate('search_categories');
  String get noTags => translate('no_tags');
  String get noCategories => translate('no_categories');
  String get noMatchingTags => translate('no_matching_tags');
  String get noMatchingCategories => translate('no_matching_categories');
  String get renameTag => translate('rename_tag');
  String get changeColor => translate('change_color');
  String get selectColor => translate('select_color');
  String get tagName => translate('tag_name');
  String get enterNewName => translate('enter_new_name');
  String get mergeTags => translate('merge_tags');
  String get mergeTagsDesc => translate('merge_tags_desc');
  String get createCategory => translate('create_category');
  String get categoryName => translate('category_name');
  String get editCategory => translate('edit_category');
  String get confirmDelete => translate('confirm_delete');
  String get deleteIrreversible => translate('delete_irreversible');

  // ============================================================
  // 收藏
  // ============================================================
  String get myFavorites => translate('my_favorites');
  String get noFavorites => translate('no_favorites');
  String get browsAndAdd => translate('brows_and_add');
  String get removedFromFavorites => translate('removed_from_favorites');

  // ============================================================
  // 认证
  // ============================================================
  String get login => translate('login');
  String get register => translate('register');
  String get username => translate('username');
  String get password => translate('password');
  String get nickname => translate('nickname');
  String get loginFailed => translate('login_failed');
  String get registerFailed => translate('register_failed');
  String get serverConfig => translate('server_config');
  String get cannotConnectServer => translate('cannot_connect_server');

  // 登录方式 / 邮箱验证码
  String get loginWithPassword => translate('login_with_password');
  String get loginWithEmailCode => translate('login_with_email_code');
  String get email => translate('email');
  String get emailCode => translate('email_code');
  String get sendCode => translate('send_code');
  String get resendCode => translate('resend_code');
  String get codeSent => translate('code_sent');
  String get codeLogin => translate('code_login');
  String get invalidEmail => translate('invalid_email');
  String get invalidCode => translate('invalid_code');

  // TOTP 二次验证
  String get totpTitle => translate('totp_title');
  String get totpHint => translate('totp_hint');
  String get totpCode => translate('totp_code');
  String get verify => translate('verify');
  String get useRecoveryCode => translate('use_recovery_code');
  String get recoveryCode => translate('recovery_code');
  String get totpRequired => translate('totp_required');

  // SSO
  String get ssoLogin => translate('sso_login');
  String get orContinueWith => translate('or_continue_with');

  // 账户安全
  String get accountSecurity => translate('account_security');
  String get securityEmail => translate('security_email');
  String get emailVerified => translate('email_verified');
  String get emailNotVerified => translate('email_not_verified');
  String get twoFactorAuth => translate('two_factor_auth');
  String get twoFactorEnabled => translate('two_factor_enabled');
  String get twoFactorDisabled => translate('two_factor_disabled');
  String get linkedAccounts => translate('linked_accounts');

  // 邮箱绑定
  String get bindEmail => translate('bind_email');
  String get bindEmailDesc => translate('bind_email_desc');
  String get bindEmailSuccess => translate('bind_email_success');
  String get emailAlreadyBound => translate('email_already_bound');
  String get verifyEmail => translate('verify_email');
  String get verifyEmailDesc => translate('verify_email_desc');
  String get emailVerifiedSuccess => translate('email_verified_success');

  // TOTP 绑定
  String get totpSetup => translate('totp_setup');
  String get totpSetupDesc => translate('totp_setup_desc');
  String get totpSecret => translate('totp_secret');
  String get totpEnable => translate('totp_enable');
  String get totpDisable => translate('totp_disable');
  String get totpEnabledSuccess => translate('totp_enabled_success');
  String get totpDisabledSuccess => translate('totp_disabled_success');
  String get recoveryCodes => translate('recovery_codes');
  String get recoveryCodesDesc => translate('recovery_codes_desc');
  String get copiedToClipboard => translate('copied_to_clipboard');

  // OIDC 身份管理
  String get linkedIdentity => translate('linked_identity');
  String get unlink => translate('unlink');
  String get unlinkConfirm => translate('unlink_confirm');
  String get noLinkedAccounts => translate('no_linked_accounts');
  String get linkAccount => translate('link_account');
  String get identityIssuer => translate('identity_issuer');
  String get identitySubject => translate('identity_subject');
  String get unlinkSuccess => translate('unlink_success');

  // OIDC 登录流程
  String get oidcNotEnabled => translate('oidc_not_enabled');
  String get linkSuccess => translate('link_success');
  String get oidcErrorGeneric => translate('oidc_error_generic');
  String get oidcErrorState => translate('oidc_error_state');
  String get oidcErrorProvider => translate('oidc_error_provider');
  String get oidcErrorCode => translate('oidc_error_code');
  String get oidcErrorExchange => translate('oidc_error_exchange');
  String get oidcErrorNonce => translate('oidc_error_nonce');
  String get oidcErrorClaims => translate('oidc_error_claims');
  String get oidcErrorNotLinked => translate('oidc_error_not_linked');
  String get oidcErrorLinkConflict => translate('oidc_error_link_conflict');
  String get oidcErrorLinkFailed => translate('oidc_error_link_failed');
  String get oidcErrorProvisionFailed =>
      translate('oidc_error_provision_failed');
  String get oidcErrorInternal => translate('oidc_error_internal');
  String get oidcErrorNetwork => translate('oidc_error_network');
  String get oidcErrorNoSession => translate('oidc_error_no_session');
  String get oidcErrorUnsupported => translate('oidc_error_unsupported');

  // 登录流程补充
  String get backToLogin => translate('back_to_login');
  String get totpMustSetupHint => translate('totp_must_setup_hint');
  String get totpCodeOrRecoveryHint => translate('totp_code_or_recovery_hint');
  String get registerEmailHint => translate('register_email_hint');

  // 账户安全补充
  String get accountSecurityDesc => translate('account_security_desc');
  String get changeEmail => translate('change_email');
  String get emailNotBound => translate('email_not_bound');
  String get emailUnverifiedHint => translate('email_unverified_hint');
  String get copy => translate('copy');
  String get copyAll => translate('copy_all');
  String get setup => translate('setup');
  String get loadFailed => translate('load_failed');
  String get operationFailed => translate('operation_failed');
  String get totpDisablePrompt => translate('totp_disable_prompt');
  String get recoveryCodesWarning => translate('recovery_codes_warning');
  String get recoveryCodesSaved => translate('recovery_codes_saved');

  // 管理员：认证与安全配置
  String get authSecurity => translate('auth_security');
  String get authSecurityDesc => translate('auth_security_desc');
  String get saved => translate('saved');
  String get saveFailed => translate('save_failed');
  String get requiredField => translate('required_field');
  String get invalidPort => translate('invalid_port');
  // SMTP
  String get smtpSection => translate('smtp_section');
  String get smtpEnabled => translate('smtp_enabled');
  String get smtpEnabledHint => translate('smtp_enabled_hint');
  String get smtpHost => translate('smtp_host');
  String get smtpPort => translate('smtp_port');
  String get smtpFrom => translate('smtp_from');
  String get smtpFromName => translate('smtp_from_name');
  String get smtpTlsMode => translate('smtp_tls_mode');
  String get secretKeptHint => translate('secret_kept_hint');
  String get tlsModeNone => translate('tls_mode_none');
  String get tlsModeStarttls => translate('tls_mode_starttls');
  String get tlsModeSsl => translate('tls_mode_ssl');
  String get smtpTest => translate('smtp_test');
  String get smtpTestRecipient => translate('smtp_test_recipient');
  String get smtpTestSuccess => translate('smtp_test_success');
  String get smtpTestFailed => translate('smtp_test_failed');
  // 邮箱验证策略
  String get emailPolicySection => translate('email_policy_section');
  String get emailVerificationRequired =>
      translate('email_verification_required');
  String get emailVerificationRequiredHint =>
      translate('email_verification_required_hint');
  String get emailCodeLoginEnabled => translate('email_code_login_enabled');
  String get emailCodeLoginHint => translate('email_code_login_hint');
  // TOTP 策略
  String get totpPolicySection => translate('totp_policy_section');
  String get totpRequiredForAdmins => translate('totp_required_for_admins');
  String get totpRequiredForAdminsHint =>
      translate('totp_required_for_admins_hint');
  String get totpIssuer => translate('totp_issuer');
  String get totpIssuerHint => translate('totp_issuer_hint');
  // OIDC
  String get oidcSection => translate('oidc_section');
  String get oidcEnabled => translate('oidc_enabled');
  String get oidcIssuerUrl => translate('oidc_issuer_url');
  String get oidcClientId => translate('oidc_client_id');
  String get oidcClientSecret => translate('oidc_client_secret');
  String get oidcScopes => translate('oidc_scopes');
  String get oidcButtonLabel => translate('oidc_button_label');
  String get oidcAutoCreateUsers => translate('oidc_auto_create_users');
  String get oidcCallbackUrl => translate('oidc_callback_url');
  String get oidcCallbackHint => translate('oidc_callback_hint');

  // ============================================================
  // 阅读器
  // ============================================================
  String get novel => translate('novel');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['zh', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// ============================================================
// 简体中文翻译
// ============================================================
const Map<String, String> _zhStrings = {
  // 通用
  'app_title': 'NowenReader',
  'cancel': '取消',
  'confirm': '确定',
  'save': '保存',
  'delete': '删除',
  'edit': '编辑',
  'create': '创建',
  'refresh': '刷新',
  'search': '搜索',
  'close': '关闭',
  'loading': '加载中...',
  'no_data': '暂无数据',
  'error': '出错了',
  'retry': '重试',
  'select_all': '全选',
  'batch_delete': '批量删除',

  // 导航
  'nav_home': '首页',
  'nav_search': '搜索',
  'nav_stats': '统计',
  'nav_settings': '设置',

  // 首页
  'sort_added_at': '添加时间',
  'sort_title': '标题',
  'sort_last_read': '最近阅读',
  'sort_rating': '评分',
  'sort_page_count': '页数',
  'filter_all': '全部',
  'filter_comic': '漫画',
  'filter_novel': '小说',
  'filter_favorites': '⭐ 收藏',
  'no_content': '暂无内容',

  // 设置
  'settings': '设置',
  'account': '账户',
  'admin': '管理员',
  'user': '普通用户',
  'server_address': '服务器地址',
  'server_info': '服务器信息',
  'about': '关于',
  'version': '版本',
  'data_management': '数据管理',
  'batch_scrape_metadata': '批量刮削元数据',
  'batch_scrape_desc': '从在线数据源自动获取元数据',
  'logout': '退出登录',
  'logout_confirm': '确定要退出登录吗？',
  'switch_server': '切换服务器',
  'tag_manager': '标签与分类管理',
  'favorites': '我的收藏',

  // 标签管理
  'tag_manager_title': '标签与分类管理',
  'tags': '标签',
  'categories': '分类',
  'search_tags': '搜索标签...',
  'search_categories': '搜索分类...',
  'no_tags': '暂无标签',
  'no_categories': '暂无分类',
  'no_matching_tags': '未找到匹配的标签',
  'no_matching_categories': '未找到匹配的分类',
  'rename_tag': '重命名标签',
  'change_color': '修改颜色',
  'select_color': '选择颜色',
  'tag_name': '标签名称',
  'enter_new_name': '输入新名称',
  'merge_tags': '合并标签',
  'merge_tags_desc': '选择要保留的目标标签（其他标签将合并到该标签）：',
  'create_category': '新建分类',
  'category_name': '分类名称',
  'edit_category': '编辑分类',
  'confirm_delete': '确认删除',
  'delete_irreversible': '此操作不可撤销。',

  // 收藏
  'my_favorites': '我的收藏',
  'no_favorites': '暂无收藏',
  'brows_and_add': '浏览书架并添加收藏',
  'removed_from_favorites': '已取消收藏',

  // 认证
  'login': '登录',
  'register': '注册',
  'username': '用户名',
  'password': '密码',
  'nickname': '昵称',
  'login_failed': '登录失败',
  'register_failed': '注册失败',
  'server_config': '服务器配置',
  'cannot_connect_server': '无法连接到服务器',

  // 登录方式 / 邮箱验证码
  'login_with_password': '密码登录',
  'login_with_email_code': '邮箱验证码登录',
  'email': '邮箱',
  'email_code': '邮箱验证码',
  'send_code': '发送验证码',
  'resend_code': '重新发送',
  'code_sent': '验证码已发送',
  'code_login': '验证码登录',
  'invalid_email': '邮箱格式不正确',
  'invalid_code': '验证码无效或已过期',

  // TOTP 二次验证
  'totp_title': '两步验证',
  'totp_hint': '请输入身份验证器中的 6 位验证码',
  'totp_code': '验证码',
  'verify': '验证',
  'use_recovery_code': '使用恢复码',
  'recovery_code': '恢复码',
  'totp_required': '请输入两步验证码',

  // SSO
  'sso_login': '使用 SSO 登录',
  'or_continue_with': '或使用其他方式',

  // 账户安全
  'account_security': '账户安全',
  'security_email': '登录邮箱',
  'email_verified': '已验证',
  'email_not_verified': '未验证',
  'two_factor_auth': '两步验证',
  'two_factor_enabled': '已启用',
  'two_factor_disabled': '未启用',
  'linked_accounts': '关联账户',

  // 邮箱绑定
  'bind_email': '绑定邮箱',
  'bind_email_desc': '绑定邮箱后可用于验证码登录与找回账户',
  'bind_email_success': '邮箱绑定成功',
  'email_already_bound': '该邮箱已被其他账户绑定',
  'verify_email': '验证邮箱',
  'verify_email_desc': '请输入发送到该邮箱的验证码',
  'email_verified_success': '邮箱验证成功',

  // TOTP 绑定
  'totp_setup': '设置两步验证',
  'totp_setup_desc': '使用身份验证器扫描二维码，或手动输入密钥',
  'totp_secret': '密钥',
  'totp_enable': '启用两步验证',
  'totp_disable': '关闭两步验证',
  'totp_enabled_success': '两步验证已启用',
  'totp_disabled_success': '两步验证已关闭',
  'recovery_codes': '恢复码',
  'recovery_codes_desc': '请妥善保存以下恢复码，每个只能使用一次',
  'copied_to_clipboard': '已复制到剪贴板',

  // OIDC 身份管理
  'linked_identity': '关联身份',
  'unlink': '解绑',
  'unlink_confirm': '确定要解绑该身份吗？',
  'no_linked_accounts': '暂未关联任何账户',
  'link_account': '关联账户',
  'identity_issuer': '身份提供方',
  'identity_subject': '用户标识',
  'unlink_success': '已解绑',

  // OIDC 登录流程
  'oidc_not_enabled': '管理员未启用 OIDC 登录',
  'link_success': '账户已关联',
  'oidc_error_generic': '登录失败，请重试',
  'oidc_error_state': '登录会话校验失败，请重试',
  'oidc_error_provider': '身份提供方返回了错误',
  'oidc_error_code': '授权码无效或已过期',
  'oidc_error_exchange': '无法与身份提供方交换令牌',
  'oidc_error_nonce': '登录校验失败（nonce 不匹配）',
  'oidc_error_claims': '身份提供方返回的用户信息不完整',
  'oidc_error_not_linked': '该外部账户尚未关联任何本地账户',
  'oidc_error_link_conflict': '该外部账户已关联到其他账户',
  'oidc_error_link_failed': '关联账户失败，请重试',
  'oidc_error_provision_failed': '自动创建账户失败',
  'oidc_error_internal': '服务器内部错误，请稍后重试',
  'oidc_error_network': '网络请求失败，请检查连接',
  'oidc_error_no_session': '登录已完成，但未能读取会话，请重试',
  'oidc_error_unsupported': '当前平台不支持 WebView 登录',

  // 登录流程补充
  'back_to_login': '返回登录',
  'totp_must_setup_hint': '管理员建议尽快开启两步验证，可在「账户安全」中设置',
  'totp_code_or_recovery_hint': '6 位验证码，或恢复码',
  'register_email_hint': '用于验证码登录与找回账户',

  // 账户安全补充
  'account_security_desc': '邮箱绑定与两步验证',
  'change_email': '更换邮箱',
  'email_not_bound': '未绑定邮箱',
  'email_unverified_hint': '该邮箱尚未验证，验证后可用于验证码登录',
  'copy': '复制',
  'copy_all': '复制全部',
  'setup': '设置',
  'load_failed': '加载失败',
  'operation_failed': '操作失败',
  'totp_disable_prompt': '请输入当前验证码或恢复码以关闭两步验证',
  'recovery_codes_warning': '恢复码只显示一次，请立即保存',
  'recovery_codes_saved': '我已保存',

  // 管理员：认证与安全配置
  'auth_security': '认证与安全',
  'auth_security_desc': 'SMTP、邮箱验证、TOTP 与 OIDC 配置',
  'saved': '已保存',
  'save_failed': '保存失败',
  'required_field': '此项为必填',
  'invalid_port': '端口需在 1-65535 之间',
  // SMTP
  'smtp_section': 'SMTP 邮件服务',
  'smtp_enabled': '启用 SMTP',
  'smtp_enabled_hint': '用于发送邮箱验证码与通知邮件',
  'smtp_host': '服务器地址',
  'smtp_port': '端口',
  'smtp_from': '发件人地址',
  'smtp_from_name': '发件人名称',
  'smtp_tls_mode': '加密方式',
  'secret_kept_hint': '已设置，留空保持不变',
  'tls_mode_none': '无',
  'tls_mode_starttls': 'STARTTLS',
  'tls_mode_ssl': 'SSL',
  'smtp_test': '发送测试邮件',
  'smtp_test_recipient': '测试收件人邮箱',
  'smtp_test_success': '测试邮件已发送',
  'smtp_test_failed': '测试邮件发送失败',
  // 邮箱验证策略
  'email_policy_section': '邮箱验证策略',
  'email_verification_required': '注册需要验证邮箱',
  'email_verification_required_hint': '新用户注册时必须填写邮箱并完成验证',
  'email_code_login_enabled': '启用邮箱验证码登录',
  'email_code_login_hint': '允许用户使用邮箱验证码免密码登录',
  // TOTP 策略
  'totp_policy_section': 'TOTP 两步验证',
  'totp_required_for_admins': '提醒管理员开启 TOTP',
  'totp_required_for_admins_hint': '仅作登录后的软提醒，不会强制管理员绑定',
  'totp_issuer': '发行者名称',
  'totp_issuer_hint': '显示在身份验证器中的名称，留空保持不变',
  // OIDC
  'oidc_section': 'OIDC 登录',
  'oidc_enabled': '启用 OIDC 登录',
  'oidc_issuer_url': 'Issuer URL',
  'oidc_client_id': 'Client ID',
  'oidc_client_secret': 'Client Secret',
  'oidc_scopes': 'Scopes',
  'oidc_button_label': '登录按钮文案',
  'oidc_auto_create_users': '首次登录自动创建用户',
  'oidc_callback_url': '回调地址（只读）',
  'oidc_callback_hint': '请在 OIDC 提供方处配置此回调地址',

  // 阅读器
  'novel': '小说',
};

// ============================================================
// English 翻译
// ============================================================
const Map<String, String> _enStrings = {
  // Common
  'app_title': 'NowenReader',
  'cancel': 'Cancel',
  'confirm': 'OK',
  'save': 'Save',
  'delete': 'Delete',
  'edit': 'Edit',
  'create': 'Create',
  'refresh': 'Refresh',
  'search': 'Search',
  'close': 'Close',
  'loading': 'Loading...',
  'no_data': 'No data',
  'error': 'Error',
  'retry': 'Retry',
  'select_all': 'Select All',
  'batch_delete': 'Batch Delete',

  // Navigation
  'nav_home': 'Home',
  'nav_search': 'Search',
  'nav_stats': 'Stats',
  'nav_settings': 'Settings',

  // Home
  'sort_added_at': 'Date Added',
  'sort_title': 'Title',
  'sort_last_read': 'Last Read',
  'sort_rating': 'Rating',
  'sort_page_count': 'Pages',
  'filter_all': 'All',
  'filter_comic': 'Comics',
  'filter_novel': 'Novels',
  'filter_favorites': '⭐ Favorites',
  'no_content': 'No content',

  // Settings
  'settings': 'Settings',
  'account': 'Account',
  'admin': 'Admin',
  'user': 'User',
  'server_address': 'Server Address',
  'server_info': 'Server Info',
  'about': 'About',
  'version': 'Version',
  'data_management': 'Data Management',
  'batch_scrape_metadata': 'Batch Scrape Metadata',
  'batch_scrape_desc': 'Auto-fetch metadata from online sources',
  'logout': 'Log Out',
  'logout_confirm': 'Are you sure you want to log out?',
  'switch_server': 'Switch Server',
  'tag_manager': 'Tags & Categories',
  'favorites': 'My Favorites',

  // Tag Manager
  'tag_manager_title': 'Tags & Categories',
  'tags': 'Tags',
  'categories': 'Categories',
  'search_tags': 'Search tags...',
  'search_categories': 'Search categories...',
  'no_tags': 'No tags',
  'no_categories': 'No categories',
  'no_matching_tags': 'No matching tags',
  'no_matching_categories': 'No matching categories',
  'rename_tag': 'Rename Tag',
  'change_color': 'Change Color',
  'select_color': 'Select Color',
  'tag_name': 'Tag Name',
  'enter_new_name': 'Enter new name',
  'merge_tags': 'Merge Tags',
  'merge_tags_desc': 'Select the target tag to keep (others will be merged into it):',
  'create_category': 'New Category',
  'category_name': 'Category Name',
  'edit_category': 'Edit Category',
  'confirm_delete': 'Confirm Delete',
  'delete_irreversible': 'This action cannot be undone.',

  // Favorites
  'my_favorites': 'My Favorites',
  'no_favorites': 'No favorites yet',
  'brows_and_add': 'Browse and add favorites',
  'removed_from_favorites': 'Removed from favorites',

  // Auth
  'login': 'Log In',
  'register': 'Register',
  'username': 'Username',
  'password': 'Password',
  'nickname': 'Nickname',
  'login_failed': 'Login failed',
  'register_failed': 'Registration failed',
  'server_config': 'Server Configuration',
  'cannot_connect_server': 'Cannot connect to server',

  // Login methods / email code
  'login_with_password': 'Password',
  'login_with_email_code': 'Email code',
  'email': 'Email',
  'email_code': 'Email code',
  'send_code': 'Send code',
  'resend_code': 'Resend code',
  'code_sent': 'Code sent',
  'code_login': 'Log in with code',
  'invalid_email': 'Invalid email address',
  'invalid_code': 'Invalid or expired code',

  // TOTP two-factor
  'totp_title': 'Two-factor authentication',
  'totp_hint': 'Enter the 6-digit code from your authenticator app',
  'totp_code': 'Verification code',
  'verify': 'Verify',
  'use_recovery_code': 'Use a recovery code',
  'recovery_code': 'Recovery code',
  'totp_required': 'Enter your two-factor code',

  // SSO
  'sso_login': 'Sign in with SSO',
  'or_continue_with': 'Or continue with',

  // Account security
  'account_security': 'Account security',
  'security_email': 'Account email',
  'email_verified': 'Verified',
  'email_not_verified': 'Not verified',
  'two_factor_auth': 'Two-factor authentication',
  'two_factor_enabled': 'Enabled',
  'two_factor_disabled': 'Disabled',
  'linked_accounts': 'Linked accounts',

  // Email binding
  'bind_email': 'Bind email',
  'bind_email_desc': 'Bind an email to enable code login and account recovery',
  'bind_email_success': 'Email bound successfully',
  'email_already_bound': 'Email already bound to another account',
  'verify_email': 'Verify email',
  'verify_email_desc': 'Enter the code sent to your email',
  'email_verified_success': 'Email verified successfully',

  // TOTP enrollment
  'totp_setup': 'Set up two-factor authentication',
  'totp_setup_desc': 'Scan the QR code with your authenticator app, or enter the key manually',
  'totp_secret': 'Secret key',
  'totp_enable': 'Enable two-factor authentication',
  'totp_disable': 'Disable two-factor authentication',
  'totp_enabled_success': 'Two-factor authentication enabled',
  'totp_disabled_success': 'Two-factor authentication disabled',
  'recovery_codes': 'Recovery codes',
  'recovery_codes_desc': 'Save these recovery codes; each can be used only once',
  'copied_to_clipboard': 'Copied to clipboard',

  // OIDC identity management
  'linked_identity': 'Linked identity',
  'unlink': 'Unlink',
  'unlink_confirm': 'Are you sure you want to unlink this identity?',
  'no_linked_accounts': 'No linked accounts',
  'link_account': 'Link an account',
  'identity_issuer': 'Provider',
  'identity_subject': 'Subject',
  'unlink_success': 'Unlinked',

  // OIDC sign-in flow
  'oidc_not_enabled': 'OIDC sign-in is not enabled',
  'link_success': 'Account linked',
  'oidc_error_generic': 'Sign-in failed. Please try again.',
  'oidc_error_state': 'Sign-in session check failed. Please try again.',
  'oidc_error_provider': 'The identity provider returned an error.',
  'oidc_error_code': 'The authorization code is invalid or expired.',
  'oidc_error_exchange':
      'Failed to exchange tokens with the identity provider.',
  'oidc_error_nonce': 'Sign-in verification failed (nonce mismatch).',
  'oidc_error_claims':
      'The identity provider returned incomplete user claims.',
  'oidc_error_not_linked':
      'This external account is not linked to any local account.',
  'oidc_error_link_conflict':
      'This external account is already linked to another account.',
  'oidc_error_link_failed': 'Failed to link the account. Please try again.',
  'oidc_error_provision_failed':
      'Failed to create a local account automatically.',
  'oidc_error_internal': 'Internal server error. Please try again later.',
  'oidc_error_network': 'Network request failed. Check your connection.',
  'oidc_error_no_session':
      'Sign-in completed but the session could not be read. Please try again.',
  'oidc_error_unsupported':
      'WebView sign-in is not supported on this platform.',

  // Login flow extras
  'back_to_login': 'Back to login',
  'totp_must_setup_hint': 'Admins are advised to enable two-factor authentication soon — set it up under Account security',
  'totp_code_or_recovery_hint': '6-digit code or recovery code',
  'register_email_hint': 'Used for code login and account recovery',

  // Account security extras
  'account_security_desc': 'Email binding and two-factor authentication',
  'change_email': 'Change email',
  'email_not_bound': 'No email bound',
  'email_unverified_hint': 'This email is not verified yet — verify it to enable code login',
  'copy': 'Copy',
  'copy_all': 'Copy all',
  'setup': 'Set up',
  'load_failed': 'Failed to load',
  'operation_failed': 'Operation failed',
  'totp_disable_prompt': 'Enter a current code or recovery code to disable two-factor authentication',
  'recovery_codes_warning': 'Recovery codes are shown only once — save them now',
  'recovery_codes_saved': "I've saved them",

  // Admin: authentication & security
  'auth_security': 'Authentication & Security',
  'auth_security_desc': 'SMTP, email verification, TOTP and OIDC settings',
  'saved': 'Saved',
  'save_failed': 'Failed to save',
  'required_field': 'This field is required',
  'invalid_port': 'Port must be between 1 and 65535',
  // SMTP
  'smtp_section': 'SMTP email',
  'smtp_enabled': 'Enable SMTP',
  'smtp_enabled_hint': 'Used to send verification codes and notification emails',
  'smtp_host': 'Host',
  'smtp_port': 'Port',
  'smtp_from': 'From address',
  'smtp_from_name': 'From name',
  'smtp_tls_mode': 'Encryption',
  'secret_kept_hint': 'Already set — leave blank to keep it',
  'tls_mode_none': 'None',
  'tls_mode_starttls': 'STARTTLS',
  'tls_mode_ssl': 'SSL',
  'smtp_test': 'Send test email',
  'smtp_test_recipient': 'Test recipient email',
  'smtp_test_success': 'Test email sent',
  'smtp_test_failed': 'Failed to send test email',
  // Email verification policy
  'email_policy_section': 'Email verification policy',
  'email_verification_required': 'Require email verification on signup',
  'email_verification_required_hint': 'New users must provide and verify an email address',
  'email_code_login_enabled': 'Enable email code login',
  'email_code_login_hint': 'Lets users sign in with an emailed code instead of a password',
  // TOTP policy
  'totp_policy_section': 'TOTP two-factor',
  'totp_required_for_admins': 'Remind admins to enable TOTP',
  'totp_required_for_admins_hint': 'Soft reminder after login only — admins are not forced to enroll',
  'totp_issuer': 'Issuer name',
  'totp_issuer_hint': 'Name shown in authenticator apps — leave blank to keep it',
  // OIDC
  'oidc_section': 'OIDC sign-in',
  'oidc_enabled': 'Enable OIDC sign-in',
  'oidc_issuer_url': 'Issuer URL',
  'oidc_client_id': 'Client ID',
  'oidc_client_secret': 'Client Secret',
  'oidc_scopes': 'Scopes',
  'oidc_button_label': 'Sign-in button label',
  'oidc_auto_create_users': 'Auto-create users on first sign-in',
  'oidc_callback_url': 'Callback URL (read-only)',
  'oidc_callback_hint': 'Configure this callback URL in your OIDC provider',

  // Reader
  'novel': 'Novel',
};
