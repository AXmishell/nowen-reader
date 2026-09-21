"use client";

import React, { useEffect, useState } from "react";
import { useAuth } from "@/lib/auth-context";
import { useTranslation } from "@/lib/i18n";
import { useSiteSettings } from "@/hooks/useSiteSettings";
import { apiPath } from "@/lib/base-path";
import { sendEmailCode } from "@/api/authSecurity";
import { User, Lock, Mail, KeyRound, Eye, EyeOff, LogIn, UserPlus, BookMarked, ShieldCheck, ShieldAlert, ArrowLeft, X } from "lucide-react";

const inputClass =
  "w-full pl-10 pr-4 py-3 bg-card border border-border rounded-lg text-foreground placeholder:text-muted/50 focus:outline-none focus:border-accent";
const passwordInputClass =
  "w-full pl-10 pr-12 py-3 bg-card border border-border rounded-lg text-foreground placeholder:text-muted/50 focus:outline-none focus:border-accent";
const primaryButtonClass =
  "w-full py-3 bg-accent text-white rounded-lg font-medium hover:bg-accent-hover disabled:opacity-50 flex items-center justify-center gap-2";
const secondaryButtonClass =
  "w-full py-3 bg-card border border-border rounded-lg font-medium text-foreground hover:bg-card-hover flex items-center justify-center gap-2";
const revealButtonClass =
  "absolute right-0 top-1/2 flex h-10 w-10 -translate-y-1/2 items-center justify-center text-muted hover:text-foreground";

/** apiClient throws plain `{status, message}` objects, so unwrap those too. */
function messageFromError(err: unknown, fallback: string): string {
  if (err instanceof Error && err.message) return err.message;
  if (typeof err === "object" && err !== null && "message" in err) {
    const message = (err as { message?: unknown }).message;
    if (typeof message === "string" && message) return message;
  }
  return fallback;
}

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const { user, loading, needsSetup, mustSetupTotp, refreshUser } = useAuth();
  const [oidcChallengeId, setOidcChallengeId] = useState("");
  const [oidcErrorCode, setOidcErrorCode] = useState<string | null>(null);

  // Consume OIDC callback query params (?oidc= / ?oidc_error=) once, then strip
  // them from the URL so a refresh does not replay them. Handled here (not just
  // on the login screen) because an oidc=ok callback may already be logged in.
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const oidc = params.get("oidc");
    const challenge = params.get("challengeId");
    const oidcError = params.get("oidc_error");
    if (!oidc && !oidcError) return;

    if (oidc === "ok") {
      void refreshUser();
    } else if (oidc === "totp" && challenge) {
      setOidcChallengeId(challenge);
    } else if (oidcError) {
      setOidcErrorCode(oidcError);
    }

    params.delete("oidc");
    params.delete("challengeId");
    params.delete("oidc_error");
    const query = params.toString();
    window.history.replaceState(
      null,
      "",
      `${window.location.pathname}${query ? `?${query}` : ""}${window.location.hash}`
    );
  }, [refreshUser]);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <div className="text-muted">Loading...</div>
      </div>
    );
  }

  if (needsSetup) {
    return <SetupPage />;
  }

  if (!user) {
    return <LoginPage initialChallengeId={oidcChallengeId} initialOidcError={oidcErrorCode} />;
  }

  return (
    <>
      {mustSetupTotp && <TotpSetupNotice />}
      {children}
    </>
  );
}

/** Non-blocking soft nudge for admins who still have to enroll TOTP. */
function TotpSetupNotice() {
  const t = useTranslation();
  const [dismissed, setDismissed] = useState(false);

  if (dismissed) return null;

  return (
    <div className="pointer-events-none fixed inset-x-0 bottom-4 z-50 flex justify-center px-4">
      <div className="pointer-events-auto flex max-w-md items-start gap-3 rounded-xl border border-amber-500/30 bg-card p-3 shadow-lg">
        <ShieldAlert className="mt-0.5 h-4 w-4 shrink-0 text-amber-400" />
        <p className="text-xs leading-relaxed text-muted">{t.auth.totpAdminNotice}</p>
        <button
          type="button"
          onClick={() => setDismissed(true)}
          aria-label={t.common.close}
          className="shrink-0 rounded-lg p-1 text-muted hover:text-foreground"
        >
          <X className="h-3.5 w-3.5" />
        </button>
      </div>
    </div>
  );
}

function SetupPage() {
  const { register } = useAuth();
  const t = useTranslation();
  const { siteName, siteIcon } = useSiteSettings();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [nickname, setNickname] = useState("");
  const [email, setEmail] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setSubmitting(true);
    try {
      await register(username, password, nickname || undefined, email.trim() || undefined);
    } catch (err) {
      setError(messageFromError(err, t.auth.operationFailed));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          {siteIcon ? (
            <img src={apiPath("/api/site-settings/icon")} alt="Site Icon" className="mx-auto mb-4 h-16 w-16 rounded-xl object-contain" />
          ) : (
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-xl bg-accent">
              <BookMarked className="h-8 w-8 text-white" />
            </div>
          )}
          <h1 className="text-3xl font-bold text-foreground mb-2">
            {siteName}
          </h1>
          <p className="text-muted">{t.auth?.setupTitle || "Create Admin Account"}</p>
          <p className="text-sm text-muted/70 mt-1">
            {t.auth?.setupDesc || "Set up the first administrator account to get started"}
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="relative">
            <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder={t.auth?.username || "Username"}
              className={inputClass}
              required
              minLength={3}
              maxLength={32}
            />
          </div>

          <div className="relative">
            <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
            <input
              type="text"
              value={nickname}
              onChange={(e) => setNickname(e.target.value)}
              placeholder={t.auth?.nickname || "Nickname (optional)"}
              className={inputClass}
            />
          </div>

          <div className="relative">
            <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder={t.auth.emailPlaceholder}
              className={inputClass}
              autoComplete="email"
            />
          </div>

          <div className="relative">
            <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
            <input
              type={showPassword ? "text" : "password"}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder={t.auth?.password || "Password"}
              className={passwordInputClass}
              required
              minLength={6}
            />
            <button
              type="button"
              onClick={() => setShowPassword(!showPassword)}
              aria-label={showPassword ? "隐藏密码" : "显示密码"}
              className={revealButtonClass}
            >
              {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </button>
          </div>

          {error && (
            <div className="text-red-400 text-sm text-center">{error}</div>
          )}

          <button
            type="submit"
            disabled={submitting}
            className={primaryButtonClass}
          >
            <UserPlus className="w-4 h-4" />
            {submitting ? (t.common.loading) : (t.auth?.createAccount || "Create Account")}
          </button>
        </form>
      </div>
    </div>
  );
}

function LoginPage({ initialChallengeId = "", initialOidcError = null }: {
  initialChallengeId?: string;
  initialOidcError?: string | null;
}) {
  const {
    login,
    register,
    registrationMode,
    loginWithEmailCode,
    verifyTotp,
    oidcProviders,
    refreshOidcProviders,
  } = useAuth();
  const t = useTranslation();
  const { siteName, siteIcon } = useSiteSettings();
  const canRegister = registrationMode === "open";
  const [isRegister, setIsRegister] = useState(false);
  const [tab, setTab] = useState<"password" | "email">("password");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [nickname, setNickname] = useState("");
  const [email, setEmail] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [emailCode, setEmailCode] = useState("");
  const [codeSent, setCodeSent] = useState(false);
  const [sendingCode, setSendingCode] = useState(false);
  const [cooldown, setCooldown] = useState(0);
  const [challengeId, setChallengeId] = useState(initialChallengeId);
  const [totpCode, setTotpCode] = useState("");
  const [oidcErrorCode, setOidcErrorCode] = useState(initialOidcError || "");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  // SSO provider discovery.
  useEffect(() => {
    void refreshOidcProviders();
  }, [refreshOidcProviders]);

  // Resend cooldown ticker for the email-code tab.
  useEffect(() => {
    if (cooldown <= 0) return;
    const timer = window.setTimeout(() => setCooldown((seconds) => seconds - 1), 1000);
    return () => window.clearTimeout(timer);
  }, [cooldown]);

  const oidcErrorMessages: Record<string, string> = {
    state: t.auth.oidcErrorState,
    exchange: t.auth.oidcErrorExchange,
    nonce: t.auth.oidcErrorNonce,
    claims: t.auth.oidcErrorClaims,
    not_linked: t.auth.oidcErrorNotLinked,
    link_conflict: t.auth.oidcErrorLinkConflict,
    provider: t.auth.oidcErrorProvider,
    code: t.auth.oidcErrorCode,
    internal: t.auth.oidcErrorInternal,
  };
  const oidcErrorMessage = oidcErrorCode
    ? (oidcErrorMessages[oidcErrorCode] || t.auth.oidcErrorGeneric)
    : "";

  const handlePasswordSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setOidcErrorCode("");
    setSubmitting(true);
    try {
      if (isRegister) {
        await register(username, password, nickname || undefined, email.trim() || undefined);
      } else {
        const outcome = await login(username, password);
        if (outcome.kind === "totp") setChallengeId(outcome.challengeId);
      }
    } catch (err) {
      setError(messageFromError(err, t.auth.operationFailed));
    } finally {
      setSubmitting(false);
    }
  };

  const handleSendCode = async () => {
    setError("");
    setOidcErrorCode("");
    const target = email.trim();
    if (!target) {
      setError(t.auth.emailRequired);
      return;
    }
    setSendingCode(true);
    try {
      // The backend answers success even when no account matches, by design.
      await sendEmailCode(target, "login");
      setCodeSent(true);
      setCooldown(60);
    } catch (err) {
      setError(messageFromError(err, t.auth.operationFailed));
    } finally {
      setSendingCode(false);
    }
  };

  const handleEmailCodeSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setOidcErrorCode("");
    const target = email.trim();
    if (!target) {
      setError(t.auth.emailRequired);
      return;
    }
    if (!emailCode.trim()) {
      setError(t.auth.codeRequired);
      return;
    }
    setSubmitting(true);
    try {
      const outcome = await loginWithEmailCode(target, emailCode.trim());
      if (outcome.kind === "totp") setChallengeId(outcome.challengeId);
    } catch (err) {
      setError(messageFromError(err, t.auth.operationFailed));
    } finally {
      setSubmitting(false);
    }
  };

  const handleTotpSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    if (!totpCode.trim()) {
      setError(t.auth.codeRequired);
      return;
    }
    setSubmitting(true);
    try {
      await verifyTotp(challengeId, totpCode.trim());
    } catch (err) {
      setError(messageFromError(err, t.auth.operationFailed));
    } finally {
      setSubmitting(false);
    }
  };

  const backToLogin = () => {
    setChallengeId("");
    setTotpCode("");
    setError("");
  };

  const subtitle = challengeId
    ? t.auth.totpTitle
    : isRegister
      ? (t.auth?.registerTitle || "Create Account")
      : (t.auth?.loginTitle || "Sign In");

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          {siteIcon ? (
            <img src={apiPath("/api/site-settings/icon")} alt="Site Icon" className="mx-auto mb-4 h-16 w-16 rounded-xl object-contain" />
          ) : (
            <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-xl bg-accent">
              <BookMarked className="h-8 w-8 text-white" />
            </div>
          )}
          <h1 className="text-3xl font-bold text-foreground mb-2">
            {siteName}
          </h1>
          <p className="text-muted">{subtitle}</p>
        </div>

        {oidcErrorMessage && (
          <div className="mb-4 flex items-start gap-2 rounded-lg border border-red-500/30 bg-red-500/10 px-3 py-2 text-sm text-red-400">
            <ShieldAlert className="mt-0.5 h-4 w-4 shrink-0" />
            <span>{oidcErrorMessage}</span>
          </div>
        )}

        {challengeId ? (
          <form onSubmit={handleTotpSubmit} className="space-y-4">
            <div className="text-center">
              <div className="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-xl bg-accent/10">
                <ShieldCheck className="h-6 w-6 text-accent" />
              </div>
              <p className="text-sm text-muted">{t.auth.totpDesc}</p>
            </div>

            <div className="relative">
              <KeyRound className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
              <input
                type="text"
                inputMode="numeric"
                autoComplete="one-time-code"
                autoFocus
                value={totpCode}
                onChange={(e) => setTotpCode(e.target.value)}
                placeholder={t.auth.totpCodePlaceholder}
                className={`${inputClass} text-center tracking-[0.3em]`}
                required
              />
            </div>
            <p className="text-xs text-muted/70 text-center">{t.auth.totpHint}</p>

            {error && (
              <div className="text-red-400 text-sm text-center">{error}</div>
            )}

            <button
              type="submit"
              disabled={submitting}
              className={primaryButtonClass}
            >
              <ShieldCheck className="w-4 h-4" />
              {submitting ? t.auth.totpVerifying : t.auth.totpVerify}
            </button>

            <button
              type="button"
              onClick={backToLogin}
              className="w-full flex items-center justify-center gap-1 text-sm text-muted hover:text-foreground"
            >
              <ArrowLeft className="w-4 h-4" />
              {t.auth.backToLogin}
            </button>
          </form>
        ) : (
          <>
            {!isRegister && (
              <div className="flex gap-1 rounded-xl bg-card p-1 mb-4">
                <button
                  type="button"
                  onClick={() => { setTab("password"); setError(""); }}
                  className={`flex-1 flex items-center justify-center gap-2 rounded-lg py-2.5 text-sm font-medium transition-colors ${
                    tab === "password" ? "bg-accent text-white shadow-sm" : "text-muted hover:text-foreground"
                  }`}
                >
                  <Lock className="h-4 w-4" />
                  {t.auth.passwordTab}
                </button>
                <button
                  type="button"
                  onClick={() => { setTab("email"); setError(""); }}
                  className={`flex-1 flex items-center justify-center gap-2 rounded-lg py-2.5 text-sm font-medium transition-colors ${
                    tab === "email" ? "bg-accent text-white shadow-sm" : "text-muted hover:text-foreground"
                  }`}
                >
                  <Mail className="h-4 w-4" />
                  {t.auth.emailCodeTab}
                </button>
              </div>
            )}

            {isRegister || tab === "password" ? (
              <form onSubmit={handlePasswordSubmit} className="space-y-4">
                <div className="relative">
                  <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
                  <input
                    type="text"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                    placeholder={t.auth?.username || "Username"}
                    className={inputClass}
                    required
                    minLength={3}
                  />
                </div>

                {isRegister && (
                  <div className="relative">
                    <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
                    <input
                      type="text"
                      value={nickname}
                      onChange={(e) => setNickname(e.target.value)}
                      placeholder={t.auth?.nickname || "Nickname"}
                      className={inputClass}
                    />
                  </div>
                )}

                {isRegister && (
                  <div className="relative">
                    <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
                    <input
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      placeholder={t.auth.emailPlaceholder}
                      className={inputClass}
                      autoComplete="email"
                    />
                  </div>
                )}

                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
                  <input
                    type={showPassword ? "text" : "password"}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder={t.auth?.password || "Password"}
                    className={passwordInputClass}
                    required
                    minLength={6}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    aria-label={showPassword ? "隐藏密码" : "显示密码"}
                    className={revealButtonClass}
                  >
                    {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>

                {error && (
                  <div className="text-red-400 text-sm text-center">{error}</div>
                )}

                <button
                  type="submit"
                  disabled={submitting}
                  className={primaryButtonClass}
                >
                  {isRegister ? <UserPlus className="w-4 h-4" /> : <LogIn className="w-4 h-4" />}
                  {submitting
                    ? t.common.loading
                    : isRegister
                      ? (t.auth?.register || "Register")
                      : (t.auth?.login || "Login")}
                </button>
              </form>
            ) : (
              <form onSubmit={handleEmailCodeSubmit} className="space-y-4">
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder={t.auth.emailPlaceholder}
                    className={`${inputClass} pr-32`}
                    autoComplete="email"
                    required
                  />
                  <button
                    type="button"
                    onClick={handleSendCode}
                    disabled={sendingCode || cooldown > 0}
                    className="absolute right-2 top-1/2 -translate-y-1/2 rounded-lg px-3 py-1.5 text-xs font-medium text-accent hover:bg-accent/10 disabled:opacity-50"
                  >
                    {sendingCode
                      ? t.auth.sendingCode
                      : cooldown > 0
                        ? t.auth.resendInSeconds.replace("{s}", String(cooldown))
                        : codeSent
                          ? t.auth.resendCode
                          : t.auth.sendCode}
                  </button>
                </div>

                {codeSent && (
                  <>
                    <p className="text-xs text-muted/70 text-center">{t.auth.codeSent}</p>
                    <div className="relative">
                      <KeyRound className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
                      <input
                        type="text"
                        inputMode="numeric"
                        autoComplete="one-time-code"
                        maxLength={6}
                        value={emailCode}
                        onChange={(e) => setEmailCode(e.target.value)}
                        placeholder={t.auth.codePlaceholder}
                        className={inputClass}
                        required
                      />
                    </div>
                  </>
                )}

                {error && (
                  <div className="text-red-400 text-sm text-center">{error}</div>
                )}

                <button
                  type="submit"
                  disabled={submitting}
                  className={primaryButtonClass}
                >
                  <LogIn className="w-4 h-4" />
                  {submitting ? t.common.loading : t.auth.loginWithCode}
                </button>
              </form>
            )}

            {oidcProviders.length > 0 && (
              <div className="mt-6">
                <div className="flex items-center gap-3 mb-4">
                  <div className="h-px flex-1 bg-border" />
                  <span className="text-xs text-muted">{t.auth.ssoDivider}</span>
                  <div className="h-px flex-1 bg-border" />
                </div>
                <div className="space-y-2">
                  {oidcProviders.map((provider) => (
                    <button
                      key={provider.id}
                      type="button"
                      onClick={() => window.location.assign(apiPath("/api/auth/oidc/login"))}
                      className={secondaryButtonClass}
                    >
                      <KeyRound className="w-4 h-4" />
                      {provider.label || t.auth.ssoLogin}
                    </button>
                  ))}
                </div>
              </div>
            )}

            <div className="text-center mt-4">
              {canRegister ? (
                <button
                  onClick={() => {
                    setIsRegister(!isRegister);
                    setError("");
                    setOidcErrorCode("");
                  }}
                  className="text-sm text-accent hover:underline"
                >
                  {isRegister
                    ? (t.auth?.hasAccount || "Already have an account? Sign in")
                    : (t.auth?.noAccount || "Don't have an account? Register")}
                </button>
              ) : (
                !isRegister && (
                  <p className="text-xs text-muted/60">
                    {registrationMode === "invite"
                      ? "请联系管理员获取账号"
                      : "注册已关闭"}
                  </p>
                )
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
