"use client";

import { useState } from "react";
import { Copy, Fingerprint, Check } from "lucide-react";
import { useTranslation } from "@/lib/i18n";
import { InlineNotice, SectionCard, TextField, ToggleRow, copyToClipboard } from "./shared";
import type { OidcDraft } from "./types";

interface OidcSettingsSectionProps {
  value: OidcDraft;
  clientSecretSet: boolean;
  callbackUrl: string;
  issuerUrlError?: string;
  clientIdError?: string;
  onChange: <K extends keyof OidcDraft>(key: K, next: OidcDraft[K]) => void;
}

export function OidcSettingsSection({
  value,
  clientSecretSet,
  callbackUrl,
  issuerUrlError,
  clientIdError,
  onChange,
}: OidcSettingsSectionProps) {
  const t = useTranslation();
  const [copyState, setCopyState] = useState<"idle" | "ok" | "error">("idle");

  const handleCopy = async () => {
    try {
      await copyToClipboard(callbackUrl);
      setCopyState("ok");
    } catch {
      setCopyState("error");
    }
    window.setTimeout(() => setCopyState("idle"), 2000);
  };

  return (
    <SectionCard
      icon={<Fingerprint className="h-4 w-4" />}
      title={t.authSecurity?.oidcTitle || "OIDC 单点登录"}
      description={
        t.authSecurity?.oidcDesc || "接入兼容 OpenID Connect 的身份提供商（Keycloak、Authentik、Authelia 等）。"
      }
    >
      <ToggleRow
        label={t.authSecurity?.oidcEnabled || "启用 OIDC 单点登录"}
        hint={t.authSecurity?.oidcEnabledHint || "启用后登录页会显示单点登录按钮；需先填写 Issuer URL 与 Client ID。"}
        checked={value.enabled}
        onChange={(next) => onChange("enabled", next)}
      />

      <div className="mt-4">
        <TextField
          id="auth-oidc-issuer"
          label={t.authSecurity?.oidcIssuerUrl || "Issuer URL"}
          type="url"
          value={value.issuerUrl}
          onChange={(next) => onChange("issuerUrl", next)}
          placeholder={t.authSecurity?.oidcIssuerUrlPlaceholder || "https://idp.example.com/realms/main"}
          error={issuerUrlError}
          autoComplete="off"
        />
      </div>

      <div className="mt-4 grid gap-4 sm:grid-cols-2">
        <TextField
          id="auth-oidc-client-id"
          label={t.authSecurity?.oidcClientId || "Client ID"}
          value={value.clientId}
          onChange={(next) => onChange("clientId", next)}
          placeholder={t.authSecurity?.oidcClientIdPlaceholder || "nowen-reader"}
          error={clientIdError}
          autoComplete="off"
        />
        <TextField
          id="auth-oidc-client-secret"
          label={t.authSecurity?.oidcClientSecret || "Client Secret"}
          type="password"
          value={value.clientSecret}
          onChange={(next) => onChange("clientSecret", next)}
          placeholder={
            clientSecretSet
              ? t.authSecurity?.oidcClientSecretKeep || "已设置，留空表示不修改"
              : t.authSecurity?.oidcClientSecretPlaceholder || "请输入 Client Secret"
          }
          autoComplete="new-password"
        />
      </div>

      <div className="mt-4 grid gap-4 sm:grid-cols-2">
        <TextField
          id="auth-oidc-scopes"
          label={t.authSecurity?.oidcScopes || "Scopes"}
          value={value.scopes}
          onChange={(next) => onChange("scopes", next)}
          placeholder={t.authSecurity?.oidcScopesPlaceholder || "openid profile email"}
          hint={t.authSecurity?.oidcScopesHint || "以空格分隔，通常为 openid profile email。"}
          autoComplete="off"
        />
        <TextField
          id="auth-oidc-button-label"
          label={t.authSecurity?.oidcButtonLabel || "登录按钮文字"}
          value={value.buttonLabel}
          onChange={(next) => onChange("buttonLabel", next)}
          placeholder={t.authSecurity?.oidcButtonLabelPlaceholder || "使用 SSO 登录"}
          autoComplete="off"
        />
      </div>

      <div className="mt-4 divide-y divide-border/40">
        <ToggleRow
          label={t.authSecurity?.oidcAutoCreateUsers || "自动创建用户"}
          hint={
            t.authSecurity?.oidcAutoCreateUsersHint ||
            "首次通过 OIDC 登录且邮箱匹配不到已有账号时，自动创建新用户。"
          }
          checked={value.autoCreateUsers}
          onChange={(next) => onChange("autoCreateUsers", next)}
        />
      </div>

      <div className="mt-5 border-t border-border pt-5">
        <div className="text-sm font-medium text-foreground">
          {t.authSecurity?.oidcCallbackUrl || "回调地址（Callback URL）"}
        </div>
        <p className="mt-1 text-xs leading-5 text-muted">
          {t.authSecurity?.oidcCallbackUrlHint ||
            "请将以下地址原样登记到身份提供商的 Redirect URI 白名单中，必须完全一致。"}
        </p>
        <div className="mt-3 flex flex-col gap-2 sm:flex-row">
          <input
            readOnly
            value={callbackUrl}
            aria-label={t.authSecurity?.oidcCallbackUrl || "回调地址（Callback URL）"}
            onFocus={(event) => event.target.select()}
            className="h-10 min-w-0 flex-1 rounded-lg border border-border bg-background px-3 font-mono text-xs text-muted outline-none"
          />
          <button
            type="button"
            onClick={handleCopy}
            disabled={!callbackUrl}
            className="inline-flex min-h-10 shrink-0 items-center justify-center gap-2 rounded-lg bg-accent/10 px-4 text-sm font-medium text-accent hover:bg-accent/20 disabled:opacity-50"
          >
            {copyState === "ok" ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
            {copyState === "ok"
              ? t.authSecurity?.copied || "已复制"
              : t.authSecurity?.copy || "复制"}
          </button>
        </div>
        {copyState === "error" && (
          <InlineNotice message={{ type: "error", text: t.authSecurity?.copyFailed || "复制失败，请手动选择并复制。" }} />
        )}
      </div>
    </SectionCard>
  );
}
