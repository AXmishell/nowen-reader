"use client";

import { useCallback, useEffect, useState } from "react";
import { AlertCircle, CheckCircle, RefreshCw, Save, Undo2 } from "lucide-react";
import { getAuthConfig, updateAuthConfig } from "@/api/authSecurity";
import { useTranslation } from "@/lib/i18n";
import { EmailPolicySection } from "./authSecurity/EmailPolicySection";
import { OidcSettingsSection } from "./authSecurity/OidcSettingsSection";
import { SmtpSettingsSection } from "./authSecurity/SmtpSettingsSection";
import { TotpPolicySection } from "./authSecurity/TotpPolicySection";
import { EMPTY_FACTS, normalizeDraft, toDraft, toPayload } from "./authSecurity/configMapping";
import { errorMessage } from "./authSecurity/shared";
import type {
  AuthSecurityDraft,
  AuthSecurityFacts,
  AuthSecurityFieldErrors,
  OidcDraft,
  SmtpDraft,
  TotpDraft,
} from "./authSecurity/types";

export function AuthSecuritySettingsPanel() {
  const t = useTranslation();
  const [draft, setDraft] = useState<AuthSecurityDraft | null>(null);
  const [savedDraft, setSavedDraft] = useState<AuthSecurityDraft | null>(null);
  const [facts, setFacts] = useState<AuthSecurityFacts>(EMPTY_FACTS);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<AuthSecurityFieldErrors>({});

  const loadConfig = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const config = await getAuthConfig();
      const next = toDraft(config);
      setDraft(next);
      setSavedDraft(next);
      setFieldErrors({});
      setFacts({
        smtpPasswordSet: config.smtp.passwordSet,
        oidcClientSecretSet: config.oidc.clientSecretSet,
        oidcCallbackUrl: config.oidc.callbackUrl,
      });
    } catch (err) {
      setError(errorMessage(err, t.authSecurity?.loadFailed || "加载认证配置失败"));
    } finally {
      setLoading(false);
    }
  }, [t]);

  useEffect(() => {
    loadConfig();
  }, [loadConfig]);

  const dirty = Boolean(draft && savedDraft && JSON.stringify(draft) !== JSON.stringify(savedDraft));

  useEffect(() => {
    if (!dirty) return;
    const warn = (event: BeforeUnloadEvent) => event.preventDefault();
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [dirty]);

  const patchSmtp = <K extends keyof SmtpDraft>(key: K, next: SmtpDraft[K]) => {
    setDraft((current) => {
      if (!current) return current;
      const smtp: SmtpDraft = { ...current.smtp };
      smtp[key] = next;
      return { ...current, smtp };
    });
    setSaved(false);
    if (key === "host") setFieldErrors((current) => ({ ...current, smtpHost: undefined }));
    if (key === "port") setFieldErrors((current) => ({ ...current, smtpPort: undefined }));
  };

  const patchTotp = <K extends keyof TotpDraft>(key: K, next: TotpDraft[K]) => {
    setDraft((current) => {
      if (!current) return current;
      const totp: TotpDraft = { ...current.totp };
      totp[key] = next;
      return { ...current, totp };
    });
    setSaved(false);
  };

  const patchOidc = <K extends keyof OidcDraft>(key: K, next: OidcDraft[K]) => {
    setDraft((current) => {
      if (!current) return current;
      const oidc: OidcDraft = { ...current.oidc };
      oidc[key] = next;
      return { ...current, oidc };
    });
    setSaved(false);
    if (key === "issuerUrl") setFieldErrors((current) => ({ ...current, oidcIssuerUrl: undefined }));
    if (key === "clientId") setFieldErrors((current) => ({ ...current, oidcClientId: undefined }));
  };

  const patchEmailPolicy = (key: "emailVerificationRequired" | "emailCodeLoginEnabled", next: boolean) => {
    setDraft((current) => {
      if (!current) return current;
      return key === "emailVerificationRequired"
        ? { ...current, emailVerificationRequired: next }
        : { ...current, emailCodeLoginEnabled: next };
    });
    setSaved(false);
  };

  const validate = (current: AuthSecurityDraft): AuthSecurityFieldErrors => {
    const errors: AuthSecurityFieldErrors = {};
    if (current.smtp.enabled) {
      if (!current.smtp.host.trim()) {
        errors.smtpHost = t.authSecurity?.smtpHostRequired || "启用 SMTP 后必须填写服务器地址";
      }
      if (!Number.isInteger(current.smtp.port) || current.smtp.port < 1 || current.smtp.port > 65535) {
        errors.smtpPort = t.authSecurity?.smtpPortError || "端口必须在 1 - 65535 之间";
      }
    }
    if (current.oidc.enabled) {
      if (!current.oidc.issuerUrl.trim()) {
        errors.oidcIssuerUrl = t.authSecurity?.oidcIssuerUrlRequired || "启用 OIDC 后必须填写 Issuer URL";
      }
      if (!current.oidc.clientId.trim()) {
        errors.oidcClientId = t.authSecurity?.oidcClientIdRequired || "启用 OIDC 后必须填写 Client ID";
      }
    }
    return errors;
  };

  const handleSave = async () => {
    if (!draft) return;
    const nextErrors = validate(draft);
    setFieldErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) {
      setSaved(false);
      return;
    }

    setSaving(true);
    setError(null);
    const sentSmtpPassword = draft.smtp.password !== "";
    const sentOidcSecret = draft.oidc.clientSecret !== "";
    try {
      await updateAuthConfig(toPayload(draft));
      const next = normalizeDraft(draft);
      setDraft(next);
      setSavedDraft(next);
      setFacts((current) => ({
        ...current,
        smtpPasswordSet: current.smtpPasswordSet || sentSmtpPassword,
        oidcClientSecretSet: current.oidcClientSecretSet || sentOidcSecret,
      }));
      setSaved(true);
      window.setTimeout(() => setSaved(false), 2000);
    } catch (err) {
      setError(errorMessage(err, t.authSecurity?.saveFailed || "保存失败"));
    } finally {
      setSaving(false);
    }
  };

  const handleDiscard = () => {
    if (!savedDraft) return;
    setDraft(savedDraft);
    setFieldErrors({});
    setError(null);
    setSaved(false);
  };

  if (loading) {
    return <div className="py-12 text-center text-sm text-muted">{t.common.loading}</div>;
  }

  if (!draft) {
    return (
      <div className="rounded-lg border border-red-500/30 bg-red-500/5 p-6 text-center">
        <AlertCircle className="mx-auto h-8 w-8 text-red-500" />
        <h2 className="mt-3 text-sm font-semibold text-foreground">
          {t.authSecurity?.loadFailed || "加载认证配置失败"}
        </h2>
        <p className="mt-1 text-xs text-muted">{error}</p>
        <button
          type="button"
          onClick={loadConfig}
          className="mt-4 inline-flex min-h-10 items-center gap-2 rounded-lg bg-accent px-4 text-sm font-medium text-white"
        >
          <RefreshCw className="h-4 w-4" />
          {t.authSecurity?.retry || "重试"}
        </button>
      </div>
    );
  }

  return (
    <div className="max-w-2xl space-y-5">
      <div>
        <h2 className="text-base font-semibold text-foreground">{t.authSecurity?.title || "认证与安全"}</h2>
        <p className="mt-1 text-sm text-muted">
          {t.authSecurity?.subtitle || "集中管理邮件发送、邮箱验证、两步验证与单点登录。"}
        </p>
      </div>

      {error && (
        <div className="flex items-center gap-2 rounded-lg border border-red-500/30 bg-red-500/5 px-4 py-3 text-sm text-red-500">
          <AlertCircle className="h-4 w-4" />
          {error}
        </div>
      )}

      <SmtpSettingsSection
        value={draft.smtp}
        passwordSet={facts.smtpPasswordSet}
        dirty={dirty}
        hostError={fieldErrors.smtpHost}
        portError={fieldErrors.smtpPort}
        onChange={patchSmtp}
      />

      <EmailPolicySection
        emailVerificationRequired={draft.emailVerificationRequired}
        emailCodeLoginEnabled={draft.emailCodeLoginEnabled}
        onChange={patchEmailPolicy}
      />

      <TotpPolicySection value={draft.totp} onChange={patchTotp} />

      <OidcSettingsSection
        value={draft.oidc}
        clientSecretSet={facts.oidcClientSecretSet}
        callbackUrl={facts.oidcCallbackUrl}
        issuerUrlError={fieldErrors.oidcIssuerUrl}
        clientIdError={fieldErrors.oidcClientId}
        onChange={patchOidc}
      />

      <div className="sticky bottom-4 flex flex-wrap items-center justify-between gap-3 rounded-lg border border-border bg-card/95 p-3 shadow-lg backdrop-blur">
        <p className="text-xs text-muted">
          {dirty ? t.authSecurity?.dirtyHint || "有尚未保存的修改" : t.authSecurity?.cleanHint || "所有认证与安全设置均已保存"}
        </p>
        <div className="flex items-center gap-2">
          <button
            type="button"
            disabled={!dirty || saving}
            onClick={handleDiscard}
            className="inline-flex min-h-10 items-center gap-2 rounded-lg px-3 text-sm text-muted hover:bg-card-hover hover:text-foreground disabled:opacity-40"
          >
            <Undo2 className="h-4 w-4" />
            {t.authSecurity?.discard || "取消修改"}
          </button>
          <button
            type="button"
            disabled={!dirty || saving}
            onClick={handleSave}
            className="inline-flex min-h-10 items-center gap-2 rounded-lg bg-accent px-4 text-sm font-medium text-white hover:bg-accent/90 disabled:opacity-40"
          >
            {saving ? <RefreshCw className="h-4 w-4 animate-spin" /> : saved ? <CheckCircle className="h-4 w-4" /> : <Save className="h-4 w-4" />}
            {saved ? t.authSecurity?.saved || "已保存" : t.authSecurity?.save || "保存配置"}
          </button>
        </div>
      </div>
    </div>
  );
}
