"use client";

import { useState } from "react";
import { AlertTriangle, Check, Copy } from "lucide-react";
import { useTranslation } from "@/lib/i18n";
import { copyText } from "./shared";

/** One-time recovery-code panel shown right after TOTP is enabled. */
export function TotpRecoveryPanel({ codes, onDone }: {
  codes: string[];
  onDone: () => void;
}) {
  const t = useTranslation();
  const text = t.accountSecurity;
  const [copied, setCopied] = useState(false);

  return (
    <div className="space-y-4">
      <div className="flex items-start gap-2 rounded-lg bg-amber-500/10 px-3 py-2.5 text-xs text-amber-400">
        <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" />
        <div>
          <p className="font-medium">{text.totpRecoveryTitle}</p>
          <p className="mt-0.5">{text.totpRecoveryWarning}</p>
        </div>
      </div>
      <div className="grid grid-cols-1 gap-1.5 sm:grid-cols-2">
        {codes.map((recoveryCode) => (
          <code
            key={recoveryCode}
            className="rounded-lg border border-border bg-background px-3 py-2 font-mono text-xs text-foreground"
          >
            {recoveryCode}
          </code>
        ))}
      </div>
      <div className="flex flex-wrap justify-end gap-2">
        <button
          type="button"
          onClick={async () => {
            try {
              await copyText(codes.join("\n"));
              setCopied(true);
            } catch {
              setCopied(false);
            }
          }}
          className="inline-flex h-9 items-center gap-2 rounded-lg bg-accent px-4 text-sm font-medium text-white hover:bg-accent/90"
        >
          {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
          {copied ? text.totpCopied : text.totpRecoveryCopyAll}
        </button>
        <button
          type="button"
          onClick={onDone}
          className="h-9 rounded-lg border border-border px-4 text-sm text-foreground hover:bg-foreground/5"
        >
          {text.totpRecoveryDone}
        </button>
      </div>
    </div>
  );
}
