"use client";

import type { ReactNode } from "react";
import { AlertCircle, CheckCircle } from "lucide-react";
import type { InlineMessage } from "./types";

/** Section card shell matching the settings panels' visual language. */
export function SectionCard({
  icon,
  title,
  description,
  children,
}: {
  icon: ReactNode;
  title: string;
  description?: string;
  children: ReactNode;
}) {
  return (
    <section className="rounded-lg border border-border bg-card p-5">
      <div className="mb-2 flex items-center gap-2">
        <span className="text-accent">{icon}</span>
        <h3 className="text-sm font-semibold text-foreground">{title}</h3>
      </div>
      {description && <p className="mb-4 text-xs leading-5 text-muted">{description}</p>}
      {children}
    </section>
  );
}

interface ToggleSwitchProps {
  checked: boolean;
  label: string;
  disabled?: boolean;
  onChange: (next: boolean) => void;
}

export function ToggleSwitch({ checked, label, disabled, onChange }: ToggleSwitchProps) {
  return (
    <button
      type="button"
      role="switch"
      aria-label={label}
      aria-checked={checked}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className={`relative h-6 w-11 shrink-0 rounded-full transition-colors disabled:opacity-50 ${
        checked ? "bg-accent" : "bg-muted/40"
      }`}
    >
      <span
        aria-hidden
        className={`absolute left-0.5 top-0.5 h-5 w-5 rounded-full bg-white shadow-sm transition-transform ${
          checked ? "translate-x-5" : "translate-x-0"
        }`}
      />
    </button>
  );
}

interface ToggleRowProps {
  label: string;
  hint?: string;
  checked: boolean;
  disabled?: boolean;
  onChange: (next: boolean) => void;
}

/** Label + one-line hint on the left, switch on the right. */
export function ToggleRow({ label, hint, checked, disabled, onChange }: ToggleRowProps) {
  return (
    <div className="flex items-start justify-between gap-4 py-3 first:pt-0 last:pb-0">
      <div className="min-w-0">
        <div className="text-sm font-medium text-foreground">{label}</div>
        {hint && <p className="mt-1 text-xs leading-5 text-muted">{hint}</p>}
      </div>
      <ToggleSwitch checked={checked} label={label} disabled={disabled} onChange={onChange} />
    </div>
  );
}

interface TextFieldProps {
  id: string;
  label: string;
  value: string | number;
  onChange: (value: string) => void;
  placeholder?: string;
  hint?: string;
  error?: string;
  type?: "text" | "password" | "email" | "url" | "number";
  autoComplete?: string;
  min?: number;
  max?: number;
  disabled?: boolean;
}

export function TextField({
  id,
  label,
  value,
  onChange,
  placeholder,
  hint,
  error,
  type = "text",
  autoComplete,
  min,
  max,
  disabled,
}: TextFieldProps) {
  return (
    <label className="block text-sm text-foreground" htmlFor={id}>
      {label}
      <input
        id={id}
        type={type}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
        autoComplete={autoComplete}
        min={min}
        max={max}
        disabled={disabled}
        className={`mt-2 h-10 w-full rounded-lg border bg-background px-3 text-sm text-foreground outline-none focus:border-accent disabled:opacity-50 ${
          error ? "border-red-500/50" : "border-border"
        }`}
      />
      {error ? (
        <span className="mt-1.5 flex items-center gap-1.5 text-xs text-red-500">
          <AlertCircle className="h-3.5 w-3.5" />
          {error}
        </span>
      ) : (
        hint && <span className="mt-1.5 block text-xs leading-5 text-muted">{hint}</span>
      )}
    </label>
  );
}

export function InlineNotice({ message }: { message: InlineMessage | null }) {
  if (!message) return null;
  const ok = message.type === "ok";
  return (
    <p className={`mt-3 flex items-center gap-2 text-xs ${ok ? "text-emerald-500" : "text-red-500"}`}>
      {ok ? <CheckCircle className="h-3.5 w-3.5" /> : <AlertCircle className="h-3.5 w-3.5" />}
      {message.text}
    </p>
  );
}

/** Shared with AccountPanel: clipboard API with a fallback for LAN HTTP deployments. */
export async function copyToClipboard(value: string): Promise<void> {
  if (navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(value);
      return;
    } catch {
      // Fall through to the legacy path below.
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

/** apiClient throws `{status, message}` objects rather than Error instances. */
export function errorMessage(error: unknown, fallback: string): string {
  if (typeof error === "object" && error !== null && "message" in error && typeof error.message === "string") {
    return error.message;
  }
  return fallback;
}
