"use client";

import { useState } from "react";
import { AlertTriangle, Check, Copy, Loader2 } from "lucide-react";
import type { TotpSetupPayload } from "@/api/authSecurity";
import { useTranslation } from "@/lib/i18n";
import { QrCodeImage } from "./QrCodeImage";
import { AccountMessageBanner, accountInputClass, copyText, type AccountMessage } from "./shared";

/** Enrollment step: QR + manual secret + confirmation code. */
export function TotpSetupPanel({ setupData, code, busy, message, onCodeChange, onSubmit, onCancel }: {
  setupData: TotpSetupPayload;
  code: string;
  busy: boolean;
  message: AccountMessage | null;
  onCodeChange: (value: string) => void;
  onSubmit: (event: React.FormEvent) => void;
  onCancel: () => void;
}) {
  const t = useTranslation();
  const text = t.accountSecurity;
  const [copied, setCopied] = useState(false);
  const [qrFailed, setQrFailed] = useState(false);

  return (
    <div className="space-y-4">
      <p className="text-xs text-muted">{text.totpScanHint}</p>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start">
        <QrCodeImage value={setupData.otpauthUrl} alt={text.totpQrAlt} onError={setQrFailed} />
        <div className="min-w-0 flex-1 space-y-2">
          <p className="text-xs font-medium text-muted">{text.totpSecretLabel}</p>
          <code className="block break-all rounded-lg border border-border bg-background p-3 font-mono text-xs text-foreground">
            {setupData.secret}
          </code>
          <button
            type="button"
            onClick={async () => {
              try {
                await copyText(setupData.secret);
                setCopied(true);
              } catch {
                setCopied(false);
              }
            }}
            className="inline-flex h-9 items-center gap-2 rounded-lg border border-border px-3 text-xs text-foreground transition-colors hover:bg-foreground/5"
          >
            {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
            {copied ? text.totpCopied : text.totpCopySecret}
          </button>
        </div>
      </div>
      {qrFailed && (
        <div className="flex items-start gap-2 rounded-lg bg-amber-500/10 px-3 py-2 text-xs text-amber-400">
          <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" />
          <span>{text.totpQrFailed}</span>
        </div>
      )}
      <form onSubmit={onSubmit} className="space-y-3">
        <label className="block text-xs font-medium text-muted">
          {text.totpCodeLabel}
          <input
            type="text"
            inputMode="numeric"
            autoComplete="one-time-code"
            maxLength={6}
            value={code}
            onChange={(event) => onCodeChange(event.target.value)}
            placeholder={text.totpCodePlaceholder}
            className={`mt-1.5 ${accountInputClass}`}
          />
        </label>
        {message && <AccountMessageBanner message={message} />}
        <div className="flex justify-end gap-2">
          <button
            type="button"
            onClick={onCancel}
            className="h-9 rounded-lg border border-border px-4 text-sm text-foreground hover:bg-foreground/5"
          >
            {t.common.cancel}
          </button>
          <button
            type="submit"
            disabled={busy || code.trim().length < 6}
            className="inline-flex h-9 items-center gap-2 rounded-lg bg-accent px-4 text-sm font-medium text-white transition-colors hover:bg-accent/90 disabled:opacity-50"
          >
            {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <Check className="h-4 w-4" />}
            {busy ? text.totpEnabling : text.totpConfirmEnable}
          </button>
        </div>
      </form>
    </div>
  );
}
