"use client";

import { useState } from "react";
import { Mail, RefreshCw, Send } from "lucide-react";
import { sendSmtpTest, type SmtpTlsMode } from "@/api/authSecurity";
import { useTranslation } from "@/lib/i18n";
import { InlineNotice, SectionCard, TextField, ToggleRow, errorMessage } from "./shared";
import type { InlineMessage, SmtpDraft } from "./types";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

interface SmtpSettingsSectionProps {
  value: SmtpDraft;
  passwordSet: boolean;
  dirty: boolean;
  hostError?: string;
  portError?: string;
  onChange: <K extends keyof SmtpDraft>(key: K, next: SmtpDraft[K]) => void;
}

export function SmtpSettingsSection({
  value,
  passwordSet,
  dirty,
  hostError,
  portError,
  onChange,
}: SmtpSettingsSectionProps) {
  const t = useTranslation();
  const [testTo, setTestTo] = useState("");
  const [testing, setTesting] = useState(false);
  const [testMessage, setTestMessage] = useState<InlineMessage | null>(null);

  const tlsModes: Array<{ value: SmtpTlsMode; label: string }> = [
    { value: "none", label: t.authSecurity?.smtpTlsNone || "不加密" },
    { value: "starttls", label: t.authSecurity?.smtpTlsStarttls || "STARTTLS" },
    { value: "ssl", label: t.authSecurity?.smtpTlsSsl || "SSL/TLS" },
  ];

  const handleTest = async () => {
    const recipient = testTo.trim() || value.from.trim();
    if (!EMAIL_PATTERN.test(recipient)) {
      setTestMessage({
        type: "error",
        text: t.authSecurity?.smtpTestInvalidRecipient || "请输入有效的收件人邮箱地址",
      });
      return;
    }

    setTesting(true);
    setTestMessage(null);
    try {
      await sendSmtpTest(recipient);
      setTestMessage({ type: "ok", text: t.authSecurity?.smtpTestSuccess || "测试邮件已发送，请检查收件箱。" });
    } catch (err) {
      const reason = errorMessage(err, t.authSecurity?.smtpTestFailed || "测试邮件发送失败");
      setTestMessage({ type: "error", text: `${t.authSecurity?.smtpTestFailed || "测试邮件发送失败"}：${reason}` });
    } finally {
      setTesting(false);
    }
  };

  return (
    <SectionCard
      icon={<Mail className="h-4 w-4" />}
      title={t.authSecurity?.smtpTitle || "SMTP 邮件"}
      description={t.authSecurity?.smtpDesc || "用于发送邮箱验证码、登录验证码与系统通知邮件。"}
    >
      <ToggleRow
        label={t.authSecurity?.smtpEnabled || "启用 SMTP 邮件发送"}
        hint={t.authSecurity?.smtpEnabledHint || "关闭后邮箱验证码等依赖邮件的功能将不可用。"}
        checked={value.enabled}
        onChange={(next) => onChange("enabled", next)}
      />

      <div className="mt-4 grid gap-4 sm:grid-cols-[minmax(0,1fr)_8rem]">
        <TextField
          id="auth-smtp-host"
          label={t.authSecurity?.smtpHost || "SMTP 服务器"}
          value={value.host}
          onChange={(next) => onChange("host", next)}
          placeholder={t.authSecurity?.smtpHostPlaceholder || "smtp.example.com"}
          error={hostError}
          autoComplete="off"
        />
        <TextField
          id="auth-smtp-port"
          label={t.authSecurity?.smtpPort || "端口"}
          type="number"
          min={1}
          max={65535}
          value={value.port === 0 ? "" : value.port}
          onChange={(next) => onChange("port", next === "" ? 0 : Number(next))}
          placeholder="587"
          error={portError}
        />
      </div>

      <div className="mt-4 grid gap-4 sm:grid-cols-2">
        <TextField
          id="auth-smtp-username"
          label={t.authSecurity?.smtpUsername || "用户名"}
          value={value.username}
          onChange={(next) => onChange("username", next)}
          placeholder={t.authSecurity?.smtpUsernamePlaceholder || "通常为完整邮箱地址"}
          autoComplete="off"
        />
        <TextField
          id="auth-smtp-password"
          label={t.authSecurity?.smtpPassword || "密码 / 授权码"}
          type="password"
          value={value.password}
          onChange={(next) => onChange("password", next)}
          placeholder={
            passwordSet
              ? t.authSecurity?.smtpPasswordKeep || "已设置，留空表示不修改"
              : t.authSecurity?.smtpPasswordPlaceholder || "请输入 SMTP 密码或授权码"
          }
          autoComplete="new-password"
        />
      </div>

      <div className="mt-4 grid gap-4 sm:grid-cols-2">
        <TextField
          id="auth-smtp-from"
          label={t.authSecurity?.smtpFrom || "发件人地址"}
          type="email"
          value={value.from}
          onChange={(next) => onChange("from", next)}
          placeholder="noreply@example.com"
          autoComplete="off"
        />
        <TextField
          id="auth-smtp-from-name"
          label={t.authSecurity?.smtpFromName || "发件人名称"}
          value={value.fromName}
          onChange={(next) => onChange("fromName", next)}
          placeholder="NowenReader"
          autoComplete="off"
        />
      </div>

      <label className="mt-4 block text-sm text-foreground" htmlFor="auth-smtp-tls">
        {t.authSecurity?.smtpTlsMode || "加密方式"}
        <select
          id="auth-smtp-tls"
          value={value.tlsMode}
          onChange={(event) => onChange("tlsMode", event.target.value as SmtpTlsMode)}
          className="mt-2 h-10 w-full rounded-lg border border-border bg-background px-3 text-sm text-foreground outline-none focus:border-accent"
        >
          {tlsModes.map((mode) => (
            <option key={mode.value} value={mode.value}>
              {mode.label}
            </option>
          ))}
        </select>
      </label>

      <div className="mt-5 border-t border-border pt-5">
        <div className="text-sm font-medium text-foreground">
          {t.authSecurity?.smtpTestTitle || "发送测试邮件"}
        </div>
        <p className="mt-1 text-xs leading-5 text-muted">
          {t.authSecurity?.smtpTestDesc || "使用已保存的 SMTP 配置发送一封测试邮件，验证配置是否可用。"}
        </p>
        <div className="mt-3 flex flex-col gap-2 sm:flex-row">
          <input
            type="email"
            value={testTo}
            onChange={(event) => {
              setTestTo(event.target.value);
              setTestMessage(null);
            }}
            placeholder={value.from || "you@example.com"}
            aria-label={t.authSecurity?.smtpTestRecipient || "收件人地址"}
            autoComplete="off"
            className="h-10 min-w-0 flex-1 rounded-lg border border-border bg-background px-3 text-sm text-foreground outline-none placeholder:text-muted/60 focus:border-accent"
          />
          <button
            type="button"
            onClick={handleTest}
            disabled={testing}
            className="inline-flex min-h-10 shrink-0 items-center justify-center gap-2 rounded-lg bg-accent/10 px-4 text-sm font-medium text-accent hover:bg-accent/20 disabled:opacity-50"
          >
            {testing ? <RefreshCw className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
            {testing
              ? t.authSecurity?.smtpTestSending || "发送中..."
              : t.authSecurity?.smtpTestSend || "发送测试邮件"}
          </button>
        </div>
        {dirty && (
          <p className="mt-2 text-xs leading-5 text-amber-500">
            {t.authSecurity?.smtpTestDirtyHint || "测试使用已保存的配置，未保存的修改不会生效。"}
          </p>
        )}
        <InlineNotice message={testMessage} />
      </div>
    </SectionCard>
  );
}
