"use client";

import { useEffect, useState } from "react";
import { Check, Info, Loader2, Mail, Send } from "lucide-react";
import { sendEmailCode, verifyEmailCode } from "@/api/authSecurity";
import { useAuth } from "@/lib/auth-context";
import { useTranslation } from "@/lib/i18n";
import {
  AccountBadge,
  AccountMessageBanner,
  AccountSectionShell,
  accountInputClass,
  getAccountErrorMessage,
  type AccountMessage,
} from "./shared";

/** Seconds before the resend button becomes available again. */
const SEND_COOLDOWN_SECONDS = 60;

export function EmailSection() {
  const t = useTranslation();
  const text = t.accountSecurity;
  const { user, refreshUser } = useAuth();
  const [code, setCode] = useState("");
  const [cooldown, setCooldown] = useState(0);
  const [sending, setSending] = useState(false);
  const [verifying, setVerifying] = useState(false);
  const [message, setMessage] = useState<AccountMessage | null>(null);

  const email = user?.email ?? "";
  const verified = Boolean(user?.emailVerified);

  useEffect(() => {
    if (cooldown <= 0) return;
    const timer = window.setTimeout(() => setCooldown(cooldown - 1), 1000);
    return () => window.clearTimeout(timer);
  }, [cooldown]);

  const handleSend = async () => {
    if (!email || sending || cooldown > 0) return;
    setSending(true);
    setMessage(null);
    try {
      await sendEmailCode(email, "verify");
      setCooldown(SEND_COOLDOWN_SECONDS);
      setMessage({ type: "success", text: text.emailCodeSent });
    } catch (err) {
      setMessage({ type: "error", text: getAccountErrorMessage(err, text.emailSendFailed) });
    } finally {
      setSending(false);
    }
  };

  const handleVerify = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!email || !code.trim() || verifying) return;
    setVerifying(true);
    setMessage(null);
    try {
      await verifyEmailCode(email, code.trim());
      setCode("");
      setMessage({ type: "success", text: text.emailVerifySuccess });
      await refreshUser();
    } catch (err) {
      setMessage({ type: "error", text: getAccountErrorMessage(err, text.emailVerifyFailed) });
    } finally {
      setVerifying(false);
    }
  };

  return (
    <AccountSectionShell
      icon={<Mail className="h-4 w-4 text-accent" />}
      title={text.emailTitle}
      description={text.emailDesc}
      action={email ? (
        <AccountBadge tone={verified ? "success" : "warning"}>
          {verified ? text.emailVerified : text.emailUnverified}
        </AccountBadge>
      ) : undefined}
    >
      {!email ? (
        <div className="flex items-start gap-2 rounded-lg bg-background px-3 py-2.5 text-xs text-muted">
          <Info className="mt-0.5 h-3.5 w-3.5 shrink-0" />
          <div>
            <p className="font-medium text-foreground">{text.emailMissing}</p>
            <p className="mt-0.5">{text.emailMissingHint}</p>
          </div>
        </div>
      ) : (
        <div className="space-y-4">
          <div className="flex items-center gap-3">
            <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-accent/10 text-accent">
              <Mail className="h-4 w-4" />
            </span>
            <p className="min-w-0 truncate text-sm font-medium text-foreground">{email}</p>
          </div>

          {!verified && (
            <form onSubmit={handleVerify} className="space-y-3">
              <button
                type="button"
                onClick={() => void handleSend()}
                disabled={sending || cooldown > 0}
                className="inline-flex h-9 items-center gap-2 rounded-lg bg-accent px-3 text-xs font-medium text-white transition-colors hover:bg-accent/90 disabled:opacity-50"
              >
                {sending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
                {cooldown > 0 ? `${text.emailSendCode} (${cooldown}s)` : text.emailSendCode}
              </button>
              <label className="block text-xs font-medium text-muted">
                {text.emailCodeLabel}
                <input
                  type="text"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  maxLength={6}
                  value={code}
                  onChange={(event) => {
                    setCode(event.target.value);
                    setMessage(null);
                  }}
                  placeholder={text.emailCodePlaceholder}
                  className={`mt-1.5 ${accountInputClass}`}
                />
              </label>
              {message && <AccountMessageBanner message={message} />}
              <div className="flex justify-end">
                <button
                  type="submit"
                  disabled={verifying || code.trim().length === 0}
                  className="inline-flex h-9 items-center gap-2 rounded-lg bg-accent px-4 text-sm font-medium text-white transition-colors hover:bg-accent/90 disabled:opacity-50"
                >
                  {verifying ? <Loader2 className="h-4 w-4 animate-spin" /> : <Check className="h-4 w-4" />}
                  {verifying ? text.emailVerifying : text.emailVerify}
                </button>
              </div>
            </form>
          )}

          {verified && message && <AccountMessageBanner message={message} />}
        </div>
      )}
    </AccountSectionShell>
  );
}
