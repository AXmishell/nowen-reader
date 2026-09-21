"use client";

import { useCallback, useEffect, useState } from "react";
import { Info, Link2, Loader2, ShieldCheck, Unlink } from "lucide-react";
import { apiPath } from "@/lib/base-path";
import {
  getOidcIdentities,
  getOidcProviders,
  unlinkOidcIdentity,
  type OidcIdentity,
  type OidcProvider,
} from "@/api/authSecurity";
import { useTranslation } from "@/lib/i18n";
import {
  AccountMessageBanner,
  AccountSectionShell,
  getAccountErrorMessage,
  type AccountMessage,
} from "./shared";

export function OidcSection() {
  const t = useTranslation();
  const text = t.accountSecurity;
  const [providers, setProviders] = useState<OidcProvider[] | null>(null);
  const [identities, setIdentities] = useState<OidcIdentity[]>([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [message, setMessage] = useState<AccountMessage | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setMessage(null);
    try {
      const [providerList, identityList] = await Promise.all([
        getOidcProviders(),
        getOidcIdentities(),
      ]);
      setProviders(providerList);
      setIdentities(identityList);
    } catch (err) {
      setMessage({ type: "error", text: getAccountErrorMessage(err, text.oidcLoadFailed) });
    } finally {
      setLoading(false);
    }
  }, [text.oidcLoadFailed]);

  useEffect(() => {
    void load();
  }, [load]);

  const handleBind = () => {
    // Top-level navigation: the backend answers with a 302 to the provider.
    window.location.assign(apiPath("/api/auth/oidc/link"));
  };

  const handleUnlink = async (identity: OidcIdentity) => {
    if (!window.confirm(text.oidcConfirmUnlink)) return;
    setBusyId(identity.id);
    setMessage(null);
    try {
      await unlinkOidcIdentity(identity.id);
      await load();
    } catch (err) {
      setMessage({ type: "error", text: getAccountErrorMessage(err, text.oidcUnlinkFailed) });
    } finally {
      setBusyId(null);
    }
  };

  const hasProviders = providers !== null && providers.length > 0;

  return (
    <AccountSectionShell
      icon={<ShieldCheck className="h-4 w-4 text-accent" />}
      title={text.oidcTitle}
      description={text.oidcDesc}
      action={hasProviders ? (
        <button
          type="button"
          onClick={handleBind}
          className="inline-flex h-9 items-center gap-2 rounded-lg bg-accent px-3 text-xs font-medium text-white transition-colors hover:bg-accent/90"
        >
          <Link2 className="h-4 w-4" />
          {text.oidcBind}
        </button>
      ) : undefined}
    >
      {loading ? (
        <div className="flex h-20 items-center justify-center text-muted">
          <Loader2 className="h-5 w-5 animate-spin" />
        </div>
      ) : (
        <div className="space-y-3">
          {providers !== null && providers.length === 0 && (
            <div className="flex items-start gap-2 rounded-lg bg-background px-3 py-2.5 text-xs text-muted">
              <Info className="mt-0.5 h-3.5 w-3.5 shrink-0" />
              <div>
                <p className="font-medium text-foreground">{text.oidcDisabled}</p>
                <p className="mt-0.5">{text.oidcDisabledHint}</p>
              </div>
            </div>
          )}

          {identities.length === 0 ? (
            hasProviders && <p className="text-sm text-muted">{text.oidcEmpty}</p>
          ) : (
            <div className="divide-y divide-border/30 overflow-hidden rounded-lg border border-border/40">
              {identities.map((identity) => (
                <div
                  key={identity.id}
                  className="flex flex-col gap-3 px-4 py-3 sm:flex-row sm:items-center sm:justify-between"
                >
                  <div className="min-w-0">
                    <p className="truncate text-sm font-medium text-foreground">
                      {identity.email || identity.subject}
                    </p>
                    <p className="mt-1 break-all text-xs text-muted">
                      {text.oidcIssuer}: {identity.issuer}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => void handleUnlink(identity)}
                    disabled={busyId === identity.id}
                    title={text.oidcUnlink}
                    aria-label={text.oidcUnlink}
                    className="inline-flex h-9 shrink-0 items-center gap-2 self-start rounded-lg border border-red-500/30 px-3 text-xs font-medium text-red-400 transition-colors hover:bg-red-500/10 disabled:opacity-50 sm:self-auto"
                  >
                    {busyId === identity.id ? (
                      <Loader2 className="h-4 w-4 animate-spin" />
                    ) : (
                      <Unlink className="h-4 w-4" />
                    )}
                    {text.oidcUnlink}
                  </button>
                </div>
              ))}
            </div>
          )}

          {message && <AccountMessageBanner message={message} />}
        </div>
      )}
    </AccountSectionShell>
  );
}
