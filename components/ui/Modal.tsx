"use client";

import { ReactNode, useEffect } from "react";
import { X } from "@phosphor-icons/react/ssr";

interface ModalProps {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
}

export function Modal({ open, onClose, title, children }: ModalProps) {
  useEffect(() => {
    if (!open) return;
    function onKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    document.addEventListener("keydown", onKeyDown);
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKeyDown);
      document.body.style.overflow = "";
    };
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="modal-title"
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
    >
      <button
        aria-label="Закрыть окно"
        className="absolute inset-0 bg-ink-950/50"
        onClick={onClose}
      />
      <div className="relative w-full max-w-md rounded-card bg-white p-6 shadow-card-hover sm:p-8">
        <div className="mb-5 flex items-start justify-between gap-4">
          <h2 id="modal-title" className="text-xl">
            {title}
          </h2>
          <button
            aria-label="Закрыть"
            onClick={onClose}
            className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-ink-500 transition hover:bg-ink-100 hover:text-ink-900"
          >
            <X size={20} weight="bold" />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}
