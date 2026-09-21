"use client";

import { KeyRound } from "lucide-react";
import { useTranslation } from "@/lib/i18n";
import { SectionCard, TextField, ToggleRow } from "./shared";
import type { TotpDraft } from "./types";

interface TotpPolicySectionProps {
  value: TotpDraft;
  onChange: <K extends keyof TotpDraft>(key: K, next: TotpDraft[K]) => void;
}

export function TotpPolicySection({ value, onChange }: TotpPolicySectionProps) {
  const t = useTranslation();

  return (
    <SectionCard
      icon={<KeyRound className="h-4 w-4" />}
      title={t.authSecurity?.totpTitle || "TOTP 两步验证"}
      description={t.authSecurity?.totpDesc || "基于时间的一次性密码（TOTP），兼容 Google Authenticator 等验证器应用。"}
    >
      <div className="divide-y divide-border/40">
        <ToggleRow
          label={t.authSecurity?.totpEnabled || "启用 TOTP"}
          hint={t.authSecurity?.totpEnabledHint || "关闭后所有用户都无法使用 TOTP 两步验证，已有绑定将暂时失效。"}
          checked={value.enabled}
          onChange={(next) => onChange("enabled", next)}
        />
        <ToggleRow
          label={t.authSecurity?.totpRequiredForAdmins || "要求管理员启用 TOTP"}
          hint={
            t.authSecurity?.totpRequiredForAdminsHint ||
            "软性提醒而非强制锁定：未启用的管理员仍可登录，但登录后会收到绑定提示。"
          }
          checked={value.requiredForAdmins}
          onChange={(next) => onChange("requiredForAdmins", next)}
        />
      </div>

      <div className="mt-4">
        <TextField
          id="auth-totp-issuer"
          label={t.authSecurity?.totpIssuer || "发行方名称（Issuer）"}
          value={value.issuer}
          onChange={(next) => onChange("issuer", next)}
          placeholder="NowenReader"
          hint={t.authSecurity?.totpIssuerHint || "显示在验证器应用中的名称；留空时使用默认站点名称。"}
          autoComplete="off"
        />
      </div>
    </SectionCard>
  );
}
