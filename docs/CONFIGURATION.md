# 配置说明

[English](./CONFIGURATION.en.md) · 简体中文

## 环境变量

| 变量 | 默认值 | 说明 |
|:---|:---|:---|
| `PORT` | `3000` | HTTP 服务监听端口 |
| `BASE_PATH` | `/` | 子路径部署前缀（例如 `/reader` 或 `/reader/`，留空或 `/` 为根部署） |
| `TRUST_PROXY_HEADERS` | `false` | 是否信任 `X-Forwarded-Proto`、`X-Forwarded-Host` 和 `X-Forwarded-Prefix`；仅在可信反向代理后启用 |
| `DATABASE_URL` | `./data/nowen-reader.db` | SQLite 数据库文件路径 |
| `COMICS_DIR` | `./comics` | 漫画主目录 |
| `NOVELS_DIR` | `./novels` | 电子书主目录 |
| `DATA_DIR` | `./.cache` | 数据/缓存目录（缩略图、页面缓存、`site-config.json`、`ai-config.json`、`secret.key`） |
| `NOWEN_SECRET_KEY` | 自动生成 | 认证密钥：加密 TOTP 密钥与 OIDC state Cookie。支持 base64 编码的 32 字节，或任意字符串（经 SHA-256 派生）。留空时首次运行自动生成并保存到 `{DATA_DIR}/secret.key`（权限 `0600`） |
| `FRONTEND_DIR` | — | 开发模式下指向独立前端构建产物；生产环境留空以使用嵌入前端 |
| `GIN_MODE` | `debug` | Gin 运行模式（`debug` 详细日志 / `release` 静默） |
| `TZ` | `Asia/Shanghai` | 时区 |
| `PUID` / `PGID` | `1001` / `1001` | Docker 内进程的 UID / GID（用于解决 bind-mount 权限问题） |
| `UMASK` | `0002` | Docker 内新建文件/目录的权限掩码；`0002` 适合 NAS/共享目录的同组写入 |
| `PERMISSION_FIX_MODE` | `auto` | Docker 启动时的权限修复模式：`auto` 自动修复，`relaxed` 在 NAS/SMB/NFS 无法 `chown` 时回退到更宽松权限，`off` 只检测不修复 |

## 子路径部署

Docker 中设置 `BASE_PATH=/reader` 后，Web、API、PWA 和 OPDS 都会挂载到 `/reader`：

```yaml
environment:
  - BASE_PATH=/reader
  - TRUST_PROXY_HEADERS=true
```

`TRUST_PROXY_HEADERS` 仅应在服务位于可信反向代理后时启用。Nginx 示例：

```nginx
location /reader/ {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

代理必须保留 `/reader` 前缀，不要在转发时将其剥离。配置完成后可通过 `/reader/api/health` 检查服务状态。

## 站点设置

可通过 Web UI 的 **设置** 面板修改，或直接编辑 `{DATA_DIR}/site-config.json`：

```json
{
  "siteName": "NowenReader",
  "comicsDir": "/app/comics",
  "extraComicsDirs": ["/mnt/manga", "/mnt/comics2"],
  "novelsDir": "/app/novels",
  "extraNovelsDirs": ["/mnt/novels2"],
  "thumbnailWidth": 400,
  "thumbnailHeight": 560,
  "pageSize": 24,
  "language": "zh-CN",
  "theme": "dark",
  "registrationMode": "open",
  "scannerConfig": {
    "syncCooldownSec": 30,
    "fsDebounceMs": 2000,
    "fullSyncBatchSize": 50,
    "quickSyncIntervalSec": 60,
    "fullSyncIntervalSec": 120,
    "md5Workers": 2
  }
}
```

### 扫描器参数详解

| 参数 | 默认值 | 说明 |
|:---|:---|:---|
| `syncCooldownSec` | 30 | 两次同步之间的最小冷却时间（秒） |
| `fsDebounceMs` | 2000 | 文件变更后延迟触发同步的防抖时间（毫秒） |
| `fullSyncBatchSize` | 50 | 完整同步每批处理的漫画数量 |
| `quickSyncIntervalSec` | 60 | 快速同步轮询间隔（秒），作为 fsnotify 兜底 |
| `fullSyncIntervalSec` | 120 | 完整同步间隔（秒），处理页数统计与 MD5 计算 |
| `md5Workers` | 2 | MD5 计算的并发数；网盘挂载场景建议设为 1–2 |

### 注册模式（registrationMode）

| 取值 | 说明 |
|:---|:---|
| `open` | 开放注册（默认），任何人可自行注册 |
| `invite` | 仅限邀请，管理员生成邀请码后方可注册 |
| `closed` | 关闭注册，仅管理员可创建账号 |

## 认证与安全（邮箱验证 / 双因素 / 单点登录）

邮箱验证码、TOTP 双因素和 OIDC 单点登录**推荐直接在 Web 管理界面的「认证与安全」面板中配置**，由后端写入 `{DATA_DIR}/site-config.json`，无需手动编辑文件。管理员接口读取配置时，SMTP 密码与 OIDC 客户端密钥只会以 `passwordSet` / `clientSecretSet` 布尔值返回，不会回显明文；保存时传入空字符串表示保留原值。以下字段供排查问题或直接编辑文件时参考。

### 邮件与邮箱策略（SMTP）

| 字段 | 默认值 | 说明 |
|:---|:---|:---|
| `smtpEnabled` | `false` | 邮件发送总开关；仅在为 `true` 且 `smtp.host` 非空时才真正启用 |
| `smtp.host` | 空 | SMTP 服务器主机名 |
| `smtp.port` | `587` | SMTP 端口 |
| `smtp.username` | 空 | SMTP 用户名；留空时不进行认证 |
| `smtp.password` | 空 | SMTP 密码 |
| `smtp.from` | 空 | 发件人地址；留空时回退使用 `smtp.username` |
| `smtp.fromName` | `NowenReader` | 发件人显示名称 |
| `smtp.tlsMode` | `starttls` | TLS 模式，仅接受 `none` / `starttls` / `ssl`；其他值按 `starttls` 处理 |
| `emailVerificationRequired` | `false` | 为 `true` 时注册必须填写邮箱；未验证邮箱的普通用户禁止登录（管理员豁免，避免把自己锁在门外） |
| `emailCodeLoginEnabled` | `false` | 是否允许邮箱验证码登录（`purpose=login` 及 `/api/auth/email/login`） |

- `tlsMode` 取值：`none` 不加密，`starttls` 通过 STARTTLS 强制升级，`ssl` 直接使用 TLS（SMTPS）。
- 邮箱验证码为 **6 位数字**，有效期 **10 分钟**，连续错误 **5 次**后失效；数据库只保存验证码的 SHA-256 摘要，不保存明文。
- 发送接口对未注册或状态不符的邮箱也返回成功，避免账号枚举。
- 关闭 `smtpEnabled` 后立即停止发信；注册、邮箱验证与邮箱验证码登录都会提示邮件未配置。

### 双因素认证（TOTP）

| 字段 | 默认值 | 说明 |
|:---|:---|:---|
| `totp.enabled` | `false` | 是否允许用户绑定 TOTP 双因素 |
| `totp.requiredForAdmins` | `false` | 是否提示管理员绑定 TOTP；这是**软提示**，登录仍会成功 |
| `totp.issuer` | `NowenReader` | 发行方名称，显示在验证器 App 中，也用于 otpauth URI |

- 用户先通过 `/api/auth/totp/setup` 获取密钥与 otpauth URI，再用 `/api/auth/totp/enable` 提交一次动态码完成绑定。
- 启用时一次性下发 **10 个恢复码**，每个只能使用一次；恢复码同样以摘要形式存储，明文只在启用响应中出现一次。
- TOTP 密钥使用 `NOWEN_SECRET_KEY` 派生的 AES-256-GCM 加密后入库。
- 管理员可在用户管理中通过 `PUT /api/auth/users`（`action=resetTotp`）重置某个用户的双因素。

### 单点登录（OIDC）

| 字段 | 默认值 | 说明 |
|:---|:---|:---|
| `oidc.enabled` | `false` | 是否启用 OIDC 单点登录 |
| `oidc.issuerUrl` | 空 | IdP 的 Issuer URL（用于自动发现） |
| `oidc.clientId` | 空 | OAuth2 客户端 ID |
| `oidc.clientSecret` | 空 | 客户端密钥；接口只返回 `clientSecretSet` |
| `oidc.scopes` | `openid profile email` | 请求的 scope，空格分隔 |
| `oidc.buttonLabel` | `OIDC` | 登录页按钮文案，也是唯一 provider 的 `label` |
| `oidc.autoCreateUsers` | `false` | 未绑定的外部身份是否自动创建本地账号 |

- 只有 `oidc.enabled=true` **且** `issuerUrl`、`clientId` 均已填写时才视为启用。
- 必须在 IdP 注册回调地址 `<BASE_PATH>/api/auth/oidc/callback`。根部署为 `/api/auth/oidc/callback`；当 `BASE_PATH=/reader` 时为 `/reader/api/auth/oidc/callback`。该地址必须与 IdP 中登记的地址完全一致。
- 登录使用授权码 + PKCE（S256）流程，并校验 state 与 nonce。
- `autoCreateUsers=false` 时，未绑定的外部身份登录会失败并跳回前端，附带 `oidc_error=not_linked`；用户需先用本地账号登录，再通过 `/api/auth/oidc/link` 绑定。

### 认证密钥（NOWEN_SECRET_KEY）

- 用途：加密数据库中保存的 TOTP 密钥，以及 OIDC 登录时写入浏览器的 state Cookie（AES-256-GCM）。
- 取值：优先读取环境变量 `NOWEN_SECRET_KEY`。若其内容是合法 base64 且解码后为 32 字节，直接作为密钥；否则对原字符串做 SHA-256，取 32 字节作为密钥。
- 缺省：未设置环境变量时，首次运行会在 `{DATA_DIR}/secret.key` 自动生成 32 字节随机密钥并落盘（权限 `0600`）。
- ⚠️ **警告**：丢失或轮换该密钥会导致已保存的 TOTP 密钥无法解密，所有已绑定用户的双因素失效（需重新绑定）；进行中的 OIDC 登录也会中断。迁移或备份时请一并保留 `secret.key`。

## AI 配置

通过 Web UI 的 **设置 → AI 面板** 配置，或编辑 `{DATA_DIR}/ai-config.json`。AI 功能完全可选，不配置不影响任何核心功能。

**国际供应商**：OpenAI / Anthropic / Google Gemini / Groq / Mistral / Cohere / Together AI / Perplexity / Fireworks 等

**国内供应商**：通义千问 / DeepSeek / 智谱 GLM / 百川 / 月之暗面 Kimi / 零一万物 / MiniMax / 讯飞星火 等

进入 **设置 → AI 面板**，选择供应商、填入 API Key、选择模型，点击「测试连接」验证后保存即可。

## 支持的文件格式

| 类型 | 格式 |
|:---|:---|
| 漫画 / 压缩包 | `.zip` `.cbz` `.cbr` `.rar` `.7z` `.cb7` `.pdf` `.azw3` |
| 小说 / 电子书 | `.txt` `.epub` `.mobi` `.azw3` `.html` `.htm` |
| 图片（压缩包内） | `.jpg` `.jpeg` `.png` `.gif` `.webp` `.bmp` `.avif` |

## 外部依赖（Docker 已内置）

| 工具 | 用途 | 是否必须 |
|:---|:---|:---|
| `p7zip` | 解压 .7z / .cb7 文件 | 可选 |
| `mupdf-tools` (mutool) | PDF 页面渲染 | 可选 |
| `libwebp-tools` (cwebp) | WebP 缩略图生成 | 可选（降级为 JPEG） |

> Docker 镜像已内置所有依赖，手动安装二进制时按需安装即可。

## 书库管理与多目录配置（推荐）

新版支持在**管理后台 → 书库管理**中创建独立书库（漫画库、小说库、混合库），每个书库可配置：

| 设置 | 说明 |
|:---|:---|
| `rootPath` | 书库根目录（支持目录浏览选择） |
| `defaultAccess` | 访问控制：`public`（所有登录用户可访问）/ `private`（仅授权用户可访问） |
| `scanEnabled` | 是否参与自动扫描 |

管理员还可以为每个用户或用户组分配书库访问权限，实现**多用户资源隔离**。

### 旧版目录配置

旧版的 `ComicsDir`、`ExtraComicsDirs`、`NovelsDir`、`ExtraNovelsDirs` 环境变量和"站点设置 → 额外漫画目录"仍然生效，但推荐使用书库管理统一管理。

1. **Docker 环境**：先在 `docker-compose.yml` 中挂载对应宿主机目录到容器内路径

   ```yaml
   volumes:
     - /your/manga/path1:/mnt/manga
     - /your/manga/path2:/mnt/comics2
   ```

2. 在**管理后台 → 书库管理**中创建书库，选择对应的**容器内路径**，例如 `/mnt/manga`，不要填写宿主机路径 `/your/manga/path1`
3. 系统会自动扫描所有已启用且 scanEnabled=true 的书库

### 上传目标书库

管理员可在首页上传区域选择目标书库：

- **选择具体书库**：文件写入该书库的 `rootPath`，并按书库类型校验文件格式
- **选择"默认目录"**（不选书库）：文件写入旧 `comicsDir` / `novelsDir`，兼容旧配置

只有满足以下条件的书库才会出现在选择列表中：
- `enabled = true`
- `rootPath` 非空
- 书库类型与当前页面内容类型匹配（漫画页显示 comic/mixed，小说页显示 novel/mixed）

**推荐**：新用户优先使用书库管理创建 `rootPath` 明确的书库，上传后系统会通过自动扫描将文件入库。

## 相关文档

- 📦 [安装指南](./INSTALL.md)
- 📚 [常见问题](./FAQ.md)
- 🛠️ [开发指南](./DEVELOPMENT.md)
