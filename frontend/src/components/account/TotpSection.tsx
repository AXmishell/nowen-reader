"use client";

import { useEffect, useState } from "react";
import { AlertTriangle, Loader2, Plus, ShieldCheck, Trash2 } from "lucide-react";
import {
  totpDisable,
  totpEnable,
  totpSetup,
  totpStatus,
  type TotpSetupPayload,
} from "@/api/authSecurity";
import { useAuth } from "@/lib/auth-context";
import { useTranslation } from "@/lib/i18n";
import { TotpRecoveryPanel } from "./TotpRecoveryPanel";
import { TotpSetupPanel } from "./TotpSetupPanel";
import {
  AccountBadge,
  AccountMessageBanner,
  AccountSectionShell,
  accountInputClass,
  getAccountErrorMessage,
  type AccountMessage,
} from "./shared";

type TotpFlow = "idle" | "setup" | "recovery" | "disable";

export function TotpSection() {
  const t = useTranslation();
  const text = t.accountSecurity;
  const { user, refreshUser } = useAuth();
  const [enabled, setEnabled] = useState(Boolean(user?.totpEnabled));
  const [flow, setFlow] = useState<TotpFlow>("idle");
  const [setupData, setSetupData] = useState<TotpSetupPayload | null>(null);
  const [code, setCode] = useState("");
  const [recoveryCodes, setRecoveryCodes] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<AccountMessage | null>(null);

  useEffect(() => {
    let cancelled = false;
    totpStatus()
      .then((value) => {
        if (!cancelled) setEnabled(value);
      })
      .catch(() => {
        // Keep the value from the auth context when the status endpoint fails.
      });
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    setEnabled(Boolean(user?.totpEnabled));
  }, [user?.totpEnabled]);

  const startSetup = async () => {
    setBusy(true);
    setMessage(null);
    try {
      const payload = await totpSetup();
      setSetupData(payload);
      setCode("");
      setFlow("setup");
    } catch (err) {
      setMessage({ type: "error", text: getAccountErrorMessage(err, text.totpSetupFailed) });
    } finally {
      setBusy(false);
    }
  };

  const cancelSetup = () => {
    setFlow("idle");
    setSetupData(null);
    setCode("");
    setMessage(null);
  };

  const confirmEnable = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!setupData || busy) return;
    setBusy(true);
    setMessage(null);
    try {
      const codes = await totpEnable(code.trim());
      setRecoveryCodes(codes);
      setSetupData(null);
      setCode("");
      setEnabled(true);
      setFlow("recovery");
      await refreshUser();
    } catch (err) {
      setMessage({ type: "error", text: getAccountErrorMessage(err, text.totpEnableFailed) });
    } finally {
      setBusy(false);
    }
  };

  const confirmDisable = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!code.trim() || busy) return;
    setBusy(true);
    setMessage(null);
    try {
      await totpDisable(code.trim());
      setEnabled(false);
      setCode("");
      setFlow("idle");
      setMessage({ type: "success", text: text.totpDisabledSuccess });
      await refreshUser();
    } catch (err) {
      setMessage({ type: "error", text: getAccountErrorMessage(err, text.totpDisableFailed) });
    } finally {
      setBusy(false);
    }
  };

  const finishRecovery = () => {
    setFlow("idle");
    setRecoveryCodes([]);
  };

  const headerAction = (
    <div className="flex items-center gap-2">
      <AccountBadge tone={enabled ? "success" : "warning"}>
        {enabled ? text.totpEnabledBadge : text.totpDisabledBadge}
      </AccountBadge>
      {flow === "idle" && (enabled ? (
        <button
          type="button"
          onClick={() => {
            setFlow("disable");
            setCode("");
            setMessage(null);
          }}
          className="inline-flex h-9 items-center gap-2 rounded-lg border border-red-500/30 px-3 text-xs font-medium text-red-400 transition-colors hover:bg-red-500/10"
        >
          <Trash2 className="h-4 w-4" />
          {text.totpDisable}
        </button>
      ) : (
        <button
          type="button"
          onClick={() => void startSetup()}
          disabled={busy}
          className="inline-flex h-9 items-center gap-2 rounded-lg bg-accent px-3 text-xs font-medium text-white transition-colors hover:bg-accent/90 disabled:opacity-50"
        >
          {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
          {text.totpEnable}
        </button>
      ))}
    </div>
  );

  return (
    <AccountSectionShell
      icon={<ShieldCheck className="h-4 w-4 text-accent" />}
      title={text.totpTitle}
      description={text.totpDesc}
      action={headerAction}
    >
      {flow === "idle" && (
        <div className="space-y-3">
          {enabled && <p className="text-xs text-muted">{text.totpEnabledHint}</p>}
          {message && <AccountMessageBanner message={message} />}
        </div>
      )}

      {flow === "setup" && setupData && (
        <TotpSetupPanel
          setupData={setupData}
          code={code}
          busy={busy}
          message={message}
          onCodeChange={(value) => {
            setCode(value);
            setMessage(null);
          }}
          onSubmit={confirmEnable}
          onCancel={cancelSetup}
        />
      )}

      {flow === "recovery" && (
        <TotpRecoveryPanel codes={recoveryCodes} onDone={finishRecovery} />
      )}

      {flow === "disable" && (
        <form onSubmit={confirmDisable} className="space-y-4">
          <div className="flex items-start gap-2 rounded-lg bg-red-500/10 px-3 py-2.5 text-xs text-red-400">
            <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" />
            <div>
              <p className="font-medium">{text.totpDisableTitle}</p>
              <p className="mt-0.5">{text.totpDisableWarning}</p>
            </div>
          </div>
          <label className="block text-xs font-medium text-muted">
            {text.totpCodeLabel}
            <input
              type="text"
              inputMode="numeric"
              autoComplete="one-time-code"
              value={code}
              onChange={(event) => {
                setCode(event.target.value);
                setMessage(null);
              }}
              placeholder={text.totpCodePlaceholder}
              className={`mt-1.5 ${accountInputClass}`}
            />
          </label>
          {message && <AccountMessageBanner message={message} />}
          <div className="flex justify-end gap-2">
            <button
              type="button"
              onClick={() => {
                setFlow("idle");
                setCode("");
                setMessage(null);
              }}
              className="h-9 rounded-lg border border-border px-4 text-sm text-foreground hover:bg-foreground/5"
            >
              {t.common.cancel}
            </button>
            <button
              type="submit"
              disabled={busy || code.trim().length === 0}
              className="inline-flex h-9 items-center gap-2 rounded-lg bg-red-500 px-4 text-sm font-medium text-white transition-colors hover:bg-red-500/90 disabled:opacity-50"
            >
              {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
              {busy ? text.totpDisabling : text.totpDisableConfirm}
            </button>
          </div>
        </form>
      )}
    </AccountSectionShell>
  );
}
