import type { SmtpTlsMode } from "@/api/authSecurity";

/**
 * Editable SMTP draft. `password` is write-only: it always starts empty and is
 * only included in the update payload when the admin actually typed a value.
 */
export interface SmtpDraft {
  enabled: boolean;
  host: string;
  port: number;
  username: string;
  password: string;
  from: string;
  fromName: string;
  tlsMode: SmtpTlsMode;
}

export interface TotpDraft {
  enabled: boolean;
  requiredForAdmins: boolean;
  issuer: string;
}

/** Editable OIDC draft; `clientSecret` follows the same write-only rule as SMTP. */
export interface OidcDraft {
  enabled: boolean;
  issuerUrl: string;
  clientId: string;
  clientSecret: string;
  scopes: string;
  buttonLabel: string;
  autoCreateUsers: boolean;
}

export interface AuthSecurityDraft {
  smtp: SmtpDraft;
  emailVerificationRequired: boolean;
  emailCodeLoginEnabled: boolean;
  totp: TotpDraft;
  oidc: OidcDraft;
}

/** Server-owned values that are never editable from this panel. */
export interface AuthSecurityFacts {
  smtpPasswordSet: boolean;
  oidcClientSecretSet: boolean;
  oidcCallbackUrl: string;
}

export interface AuthSecurityFieldErrors {
  smtpHost?: string;
  smtpPort?: string;
  oidcIssuerUrl?: string;
  oidcClientId?: string;
}

export interface InlineMessage {
  type: "ok" | "error";
  text: string;
}
