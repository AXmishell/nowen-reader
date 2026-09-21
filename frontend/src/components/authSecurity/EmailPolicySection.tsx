"use client";

import { MailCheck } from "lucide-react";
import { useTranslation } from "@/lib/i18n";
import { SectionCard, ToggleRow } from "./shared";

interface EmailPolicySectionProps {
  emailVerificationRequired: boolean;
  emailCodeLoginEnabled: boolean;
  onChange: (key: "emailVerificationRequired" | "emailCodeLoginEnabled", next: boolean) => void;
}

export function EmailPolicySection({
  emailVerificationRequired,
  emailCodeLoginEnabled,
  onChange,
}: EmailPolicySectionProps) {
  const t = useTranslation();

  return (
    <SectionCard
      icon={<MailCheck className="h-4 w-4" />}
      title={t.authSecurity?.emailTitle || "邮箱验证策略"}
      description={t.authSecurity?.emailDesc || "控制注册时的邮箱要求，以及邮箱验证与验证码登录的行为。"}
    >
      <div className="divide-y divide-border/40">
        <ToggleRow
          label={t.authSecurity?.emailVerification || "强制邮箱验证"}
          hint={
            t.authSecurity?.emailVerificationHint ||
            "开启后注册必须填写邮箱，未验证邮箱的普通用户无法登录（管理员豁免，避免锁死）。"
          }
          checked={emailVerificationRequired}
          onChange={(next) => onChange("emailVerificationRequired", next)}
        />
        <ToggleRow
          label={t.authSecurity?.emailCodeLogin || "允许邮箱验证码登录"}
          hint={
            t.authSecurity?.emailCodeLoginHint ||
            "开启后用户可使用邮箱验证码登录，无需输入密码；关闭时仅保留密码登录。"
          }
          checked={emailCodeLoginEnabled}
          onChange={(next) => onChange("emailCodeLoginEnabled", next)}
        />
      </div>
    </SectionCard>
  );
}
