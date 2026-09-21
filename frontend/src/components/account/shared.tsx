"use client";

import type { ReactNode } from "react";

export interface AccountMessage {
  type: "success" | "error";
  text: string;
}

/** Reads the message out of the plain-object errors thrown by apiClient. */
export function getAccountErrorMessage(error: unknown, fallback: string): string {
  if (typeof error === "object" && error !== null && "message" in error) {
    const message = (error as { message?: unknown }).message;
    if (typeof message === "string" && message) return message;
  }
  return fallback;
}

/** Copies text, falling back to execCommand for LAN deployments over HTTP. */
export async function copyText(value: string): Promise<void> {
  if (navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(value);
      return;
    } catch {
      // Fall back for LAN deployments served over HTTP.
    }
  }

  const textarea = document.createElement("textarea");
  textarea.value = value;
  textarea.style.position = "fixed";
  textarea.style.opacity = "0";
  document.body.appendChild(textarea);
  textarea.select();
  const copied = document.execCommand("copy");
  textarea.remove();
  if (!copied) throw new Error("Copy failed");
}

/** Section shell mirroring the card header used by the account panel sections. */
export function AccountSectionShell({ icon, title, description, action, children }: {
  icon: ReactNode;
  title: string;
  description: string;
  action?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section className="overflow-hidden rounded-2xl border border-border/40 bg-card">
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-border/30 px-5 py-4">
        <div>
          <h3 className="flex items-center gap-2 text-sm font-semibold text-foreground">
            {icon}
            {title}
          </h3>
          <p className="mt-1 text-xs text-muted">{description}</p>
        </div>
        {action}
      </div>
      <div className="p-5">{children}</div>
    </section>
  );
}

export function AccountBadge({ tone, children }: {
  tone: "success" | "warning" | "danger";
  children: ReactNode;
}) {
  const tones = {
    success: "bg-green-500/10 text-green-400",
    warning: "bg-amber-500/10 text-amber-400",
    danger: "bg-red-500/10 text-red-400",
  } as const;
  return (
    <span className={`rounded px-2 py-0.5 text-[11px] font-medium ${tones[tone]}`}>
      {children}
    </span>
  );
}

export function AccountMessageBanner({ message }: { message: AccountMessage }) {
  return (
    <div className={`text-xs px-3 py-2 rounded-lg ${
      message.type === "success"
        ? "bg-green-500/10 text-green-400"
        : "bg-red-500/10 text-red-400"
    }`}>
      {message.text}
    </div>
  );
}

export const accountInputClass =
  "w-full rounded-lg border border-border bg-background px-3 py-2.5 text-sm text-foreground placeholder:text-muted/50 focus:border-accent focus:outline-none transition-colors";
