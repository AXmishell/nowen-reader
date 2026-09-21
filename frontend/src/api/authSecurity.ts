import { apiClient } from "@/lib/apiClient";

// ============================================================
// Shared auth payloads
// ============================================================

/** Safe user object returned by the auth endpoints (never contains secrets). */
export interface AuthUser {
  id: string;
  username: string;
  nickname: string;
  role: string;
  aiEnabled: boolean;
  email: string;
  emailVerified: boolean;
  totpEnabled: boolean;
}

/** First-factor success: a session cookie was set together with the user. */
export interface AuthSessionPayload {
  user: AuthUser;
  /** Soft nudge: admins are required to use TOTP but have not enrolled yet. */
  mustSetupTotp?: boolean;
}

/** First-factor success, but a TOTP second step is still required (no session yet). */
export interface AuthTotpChallenge {
  totpRequired: true;
  challengeId: string;
}

export type AuthLoginResult = AuthSessionPayload | AuthTotpChallenge;

/** Narrows a login response to the TOTP challenge branch. */
export function isTotpChallenge(result: AuthLoginResult): result is AuthTotpChallenge {
  return "totpRequired" in result && result.totpRequired === true;
}

// ============================================================
// Email verification / email-code login
// ============================================================

export type EmailCodePurpose = "verify" | "login";

/**
 * Requests an email code. The endpoint answers `{success:true}` even when no
 * account matches the address, so a missing account is intentionally not
 * surfaced as an error by callers.
 */
export async function sendEmailCode(email: string, purpose: EmailCodePurpose): Promise<void> {
  await apiClient.post<{ success: boolean }>("/api/auth/email/send", { email, purpose });
}

export async function verifyEmailCode(email: string, code: string): Promise<void> {
  await apiClient.post<{ success: boolean }>("/api/auth/email/verify", { email, code });
}

export async function loginWithEmailCode(email: string, code: string): Promise<AuthLoginResult> {
  return apiClient.post<AuthLoginResult>("/api/auth/email/login", { email, code });
}

// ============================================================
// Self-service email binding / change (signed-in session)
// ============================================================

/**
 * Sends a verification code to an address the signed-in user wants to bind.
 * Requires a browser session; the address must not belong to another account.
 */
export async function sendEmailBindCode(email: string): Promise<void> {
  await apiClient.post<{ success: boolean }>("/api/auth/email/bind/send", { email });
}

/** Confirms the code and sets the signed-in user's email (marked verified). */
export async function verifyEmailBind(email: string, code: string): Promise<void> {
  await apiClient.post<{ success: boolean }>("/api/auth/email/bind/verify", { email, code });
}

// ============================================================
// TOTP two-factor authentication
// ============================================================

export interface TotpSetupPayload {
  /** Base32 secret, shown for manual entry / QR generation. */
  secret: string;
  /** otpauth:// URL for authenticator apps. */
  otpauthUrl: string;
}

export async function totpSetup(): Promise<TotpSetupPayload> {
  return apiClient.post<TotpSetupPayload>("/api/auth/totp/setup");
}

/** Enables TOTP and returns the one-time recovery codes. */
export async function totpEnable(code: string): Promise<string[]> {
  const response = await apiClient.post<{ recoveryCodes: string[] }>("/api/auth/totp/enable", { code });
  return response.recoveryCodes;
}

export async function totpDisable(code: string): Promise<void> {
  await apiClient.post<{ success: boolean }>("/api/auth/totp/disable", { code });
}

export async function totpStatus(): Promise<boolean> {
  const response = await apiClient.get<{ enabled: boolean }>("/api/auth/totp/status");
  return response.enabled;
}

/** Completes the login second step and returns the now-authenticated user. */
export async function totpVerify(challengeId: string, code: string): Promise<AuthUser> {
  const response = await apiClient.post<{ user: AuthUser }>("/api/auth/totp/verify", { challengeId, code });
  return response.user;
}

// ============================================================
// OIDC single sign-on
// ============================================================

export interface OidcProvider {
  id: string;
  label: string;
}

export interface OidcIdentity {
  id: string;
  issuer: string;
  subject: string;
  email: string;
}

export async function getOidcProviders(): Promise<OidcProvider[]> {
  const response = await apiClient.get<{ providers: OidcProvider[] }>("/api/auth/oidc/providers");
  return response.providers;
}

export async function getOidcIdentities(): Promise<OidcIdentity[]> {
  return apiClient.get<OidcIdentity[]>("/api/auth/oidc/identities");
}

export async function unlinkOidcIdentity(id: string): Promise<void> {
  await apiClient.delete<{ success: boolean }>(`/api/auth/oidc/identities/${encodeURIComponent(id)}`);
}

// ============================================================
// Admin auth configuration (SMTP / email / TOTP / OIDC)
// ============================================================

export type SmtpTlsMode = "none" | "starttls" | "ssl";

export interface SmtpConfig {
  enabled: boolean;
  host: string;
  port: number;
  username: string;
  passwordSet: boolean;
  from: string;
  fromName: string;
  tlsMode: SmtpTlsMode;
}

export interface TotpConfig {
  enabled: boolean;
  requiredForAdmins: boolean;
  issuer: string;
}

export interface OidcConfig {
  enabled: boolean;
  issuerUrl: string;
  clientId: string;
  clientSecretSet: boolean;
  scopes: string;
  buttonLabel: string;
  autoCreateUsers: boolean;
  callbackUrl: string;
}

export interface AuthConfig {
  smtp: SmtpConfig;
  emailVerificationRequired: boolean;
  emailCodeLoginEnabled: boolean;
  totp: TotpConfig;
  oidc: OidcConfig;
}

/**
 * Pointer-style partial update: omitted fields keep their stored value, and an
 * empty/omitted `smtp.password` or `oidc.clientSecret` keeps the stored secret.
 */
export interface AuthConfigUpdate {
  smtp?: {
    enabled?: boolean;
    host?: string;
    port?: number;
    username?: string;
    password?: string;
    from?: string;
    fromName?: string;
    tlsMode?: SmtpTlsMode;
  };
  emailVerificationRequired?: boolean;
  emailCodeLoginEnabled?: boolean;
  totp?: {
    enabled?: boolean;
    requiredForAdmins?: boolean;
    issuer?: string;
  };
  oidc?: {
    enabled?: boolean;
    issuerUrl?: string;
    clientId?: string;
    clientSecret?: string;
    scopes?: string;
    buttonLabel?: string;
    autoCreateUsers?: boolean;
  };
}

export async function getAuthConfig(): Promise<AuthConfig> {
  return apiClient.get<AuthConfig>("/api/admin/auth-config");
}

export async function updateAuthConfig(body: AuthConfigUpdate): Promise<void> {
  await apiClient.put<{ success: boolean }>("/api/admin/auth-config", body);
}

export async function sendSmtpTest(to: string): Promise<void> {
  await apiClient.post<{ success: boolean }>("/api/admin/auth-config/smtp-test", { to });
}
