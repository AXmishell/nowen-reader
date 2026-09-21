"use client";

import { apiClient } from "@/lib/apiClient";
import {
  getOidcProviders,
  isTotpChallenge,
  loginWithEmailCode as apiLoginWithEmailCode,
  totpVerify,
  type AuthLoginResult,
  type AuthUser,
  type OidcProvider,
} from "@/api/authSecurity";
import { setUserScope } from "@/hooks/useComicList";
import React, { createContext, useContext, useState, useEffect, useCallback } from "react";

/**
 * Result of a first-factor login: either the session cookie was set and the
 * user state is already populated, or a TOTP second step must be driven by the
 * caller with the returned challenge id.
 */
export type LoginOutcome =
  | { kind: "session" }
  | { kind: "totp"; challengeId: string };

interface AuthContextType {
  user: AuthUser | null;
  loading: boolean;
  needsSetup: boolean;
  registrationMode: string;
  /** Soft nudge: admins are required to use TOTP but have not enrolled yet. */
  mustSetupTotp: boolean;
  oidcProviders: OidcProvider[];
  login: (username: string, password: string) => Promise<LoginOutcome>;
  register: (username: string, password: string, nickname?: string, email?: string) => Promise<void>;
  loginWithEmailCode: (email: string, code: string) => Promise<LoginOutcome>;
  /** Completes the TOTP second step; sets the authenticated user on success. */
  verifyTotp: (challengeId: string, code: string) => Promise<void>;
  logout: () => Promise<void>;
  refreshUser: () => Promise<void>;
  refreshOidcProviders: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

/** Reads the HTTP status out of the plain-object errors thrown by apiClient. */
function errorStatus(err: unknown): number | undefined {
  if (typeof err === "object" && err !== null && "status" in err) {
    return (err as { status?: number }).status;
  }
  return undefined;
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [needsSetup, setNeedsSetup] = useState(false);
  const [registrationMode, setRegistrationMode] = useState("open");
  const [mustSetupTotp, setMustSetupTotp] = useState(false);
  const [oidcProviders, setOidcProviders] = useState<OidcProvider[]>([]);

  const applySession = useCallback((u: AuthUser) => {
    setUser(u);
    // 同步用户作用域到漫画列表缓存
    setUserScope(u.id, u.role);
    setNeedsSetup(false);
  }, []);

  /** Maps a raw login response onto the UI-facing outcome and applies the session. */
  const applyLoginResult = useCallback((data: AuthLoginResult): LoginOutcome => {
    if (isTotpChallenge(data)) {
      return { kind: "totp", challengeId: data.challengeId };
    }
    applySession(data.user);
    setMustSetupTotp(data.mustSetupTotp === true);
    return { kind: "session" };
  }, [applySession]);

  const refreshUser = useCallback(async () => {
    try {
        const data = await apiClient.get<{
          user?: AuthUser | null;
          needsSetup?: boolean;
          registrationMode?: string;
        }>("/api/auth/me");
        const u = data.user || null;
        setUser(u);
        // 同步用户作用域到漫画列表缓存
        if (u) {
          setUserScope(u.id, u.role);
        } else {
          setUserScope("", "");
        }
        setNeedsSetup(data.needsSetup || false);
        if (data.registrationMode) setRegistrationMode(data.registrationMode);
      } catch (err) {
        // Only clear user on genuine 401 (session expired / not logged in).
        // Network errors (status=0), timeouts, and 5xx should NOT log the user out,
        // as these are transient and the session cookie is still valid.
        if (errorStatus(err) === 401) {
          setUser(null);
          setUserScope("", "");
        } else {
          console.warn("[Auth] /api/auth/me failed with status", errorStatus(err), "— preserving current state");
        }
      } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refreshUser();
  }, [refreshUser]);

  const refreshOidcProviders = useCallback(async () => {
    try {
      setOidcProviders(await getOidcProviders());
    } catch {
      // OIDC 未启用或网络异常时静默降级为不显示 SSO 入口
      setOidcProviders([]);
    }
  }, []);

  const login = async (username: string, password: string): Promise<LoginOutcome> => {
    const data = await apiClient.post<AuthLoginResult>("/api/auth/login", { username, password });
    return applyLoginResult(data);
  };

  const loginWithEmailCode = async (email: string, code: string): Promise<LoginOutcome> => {
    const data = await apiLoginWithEmailCode(email, code);
    return applyLoginResult(data);
  };

  const verifyTotp = async (challengeId: string, code: string) => {
    const u = await totpVerify(challengeId, code);
    applySession(u);
    setMustSetupTotp(false);
  };

  const register = async (username: string, password: string, nickname?: string, email?: string) => {
    const data = await apiClient.post<{ user: AuthUser }>("/api/auth/register", {
      username,
      password,
      nickname,
      email: email || undefined,
    });
    applySession(data.user);
  };

  const logout = async () => {
    try { await apiClient.post("/api/auth/logout"); } catch { /* ignore */ }
    setUser(null);
    setMustSetupTotp(false);
    setUserScope("", "");
  };

  return (
    <AuthContext.Provider value={{
      user,
      loading,
      needsSetup,
      registrationMode,
      mustSetupTotp,
      oidcProviders,
      login,
      register,
      loginWithEmailCode,
      verifyTotp,
      logout,
      refreshUser,
      refreshOidcProviders,
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth must be used within AuthProvider");
  return context;
}

export type { AuthUser, OidcProvider } from "@/api/authSecurity";
