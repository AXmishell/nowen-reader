"use client";

import { useEffect, useState } from "react";
import { toDataURL } from "qrcode";
import { Loader2 } from "lucide-react";

const QR_SIZE = 192;

/** Renders an otpauth:// URI as a scannable PNG data-URL image. */
export function QrCodeImage({ value, alt, onError }: {
  value: string;
  alt: string;
  onError?: (failed: boolean) => void;
}) {
  const [dataUrl, setDataUrl] = useState("");

  useEffect(() => {
    let cancelled = false;
    setDataUrl("");
    onError?.(false);
    toDataURL(value, { width: QR_SIZE, margin: 1, errorCorrectionLevel: "M" })
      .then((url) => {
        if (!cancelled) setDataUrl(url);
      })
      .catch(() => {
        if (!cancelled) onError?.(true);
      });
    return () => {
      cancelled = true;
    };
  }, [value, onError]);

  if (!dataUrl) {
    return (
      <div className="flex h-44 w-44 shrink-0 items-center justify-center self-center rounded-lg border border-dashed border-border text-muted">
        <Loader2 className="h-5 w-5 animate-spin" />
      </div>
    );
  }

  return (
    <img
      src={dataUrl}
      alt={alt}
      className="h-44 w-44 shrink-0 self-center rounded-lg bg-white p-1.5"
      draggable={false}
    />
  );
}
