import type { AuthConfig, AuthConfigUpdate } from "@/api/authSecurity";
import type { AuthSecurityDraft, AuthSecurityFacts } from "./types";

export const EMPTY_FACTS: AuthSecurityFacts = {
  smtpPasswordSet: false,
  oidcClientSecretSet: false,
  oidcCallbackUrl: "",
};

/** Server response → editable draft. Secrets are never copied into state. */
export function toDraft(config: AuthConfig): AuthSecurityDraft {
  return {
    smtp: {
      enabled: config.smtp.enabled,
      host: config.smtp.host,
      port: config.smtp.port,
      username: config.smtp.username,
      password: "",
      from: config.smtp.from,
      fromName: config.smtp.fromName,
      tlsMode: config.smtp.tlsMode,
    },
    emailVerificationRequired: config.emailVerificationRequired,
    emailCodeLoginEnabled: config.emailCodeLoginEnabled,
    totp: {
      enabled: config.totp.enabled,
      requiredForAdmins: config.totp.requiredForAdmins,
      issuer: config.totp.issuer,
    },
    oidc: {
      enabled: config.oidc.enabled,
      issuerUrl: config.oidc.issuerUrl,
      clientId: config.oidc.clientId,
      clientSecret: "",
      scopes: config.oidc.scopes,
      buttonLabel: config.oidc.buttonLabel,
      autoCreateUsers: config.oidc.autoCreateUsers,
    },
  };
}

/** Trimmed server state used for dirty comparison and for discarding edits. */
export function normalizeDraft(draft: AuthSecurityDraft): AuthSecurityDraft {
  return {
    smtp: {
      ...draft.smtp,
      host: draft.smtp.host.trim(),
      username: draft.smtp.username.trim(),
      from: draft.smtp.from.trim(),
      fromName: draft.smtp.fromName.trim(),
      password: "",
    },
    emailVerificationRequired: draft.emailVerificationRequired,
    emailCodeLoginEnabled: draft.emailCodeLoginEnabled,
    totp: { ...draft.totp, issuer: draft.totp.issuer.trim() },
    oidc: {
      ...draft.oidc,
      issuerUrl: draft.oidc.issuerUrl.trim(),
      clientId: draft.oidc.clientId.trim(),
      scopes: draft.oidc.scopes.trim(),
      buttonLabel: draft.oidc.buttonLabel.trim(),
      clientSecret: "",
    },
  };
}

/** Pointer-style payload: a blank secret is omitted so the stored one is kept. */
export function toPayload(draft: AuthSecurityDraft): AuthConfigUpdate {
  return {
    smtp: {
      enabled: draft.smtp.enabled,
      host: draft.smtp.host.trim(),
      port: draft.smtp.port,
      username: draft.smtp.username.trim(),
      from: draft.smtp.from.trim(),
      fromName: draft.smtp.fromName.trim(),
      tlsMode: draft.smtp.tlsMode,
      ...(draft.smtp.password !== "" ? { password: draft.smtp.password } : {}),
    },
    emailVerificationRequired: draft.emailVerificationRequired,
    emailCodeLoginEnabled: draft.emailCodeLoginEnabled,
    totp: {
      enabled: draft.totp.enabled,
      requiredForAdmins: draft.totp.requiredForAdmins,
      issuer: draft.totp.issuer.trim(),
    },
    oidc: {
      enabled: draft.oidc.enabled,
      issuerUrl: draft.oidc.issuerUrl.trim(),
      clientId: draft.oidc.clientId.trim(),
      scopes: draft.oidc.scopes.trim(),
      buttonLabel: draft.oidc.buttonLabel.trim(),
      autoCreateUsers: draft.oidc.autoCreateUsers,
      ...(draft.oidc.clientSecret !== "" ? { clientSecret: draft.oidc.clientSecret } : {}),
    },
  };
}
