"use client";

import { type FormEvent, useState } from "react";

export function ResendForm() {
  const [email, setEmail] = useState("");
  const [sending, setSending] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setSending(true);

    try {
      const response = await fetch("/api/licenses/resend", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email }),
      });
      const body = (await response.json()) as { message?: string };

      setMessage(
        body.message ??
          "If that email has an Edith licence, the key is on its way to it.",
      );
    } catch {
      setMessage("Something went wrong. Please try again in a moment.");
    } finally {
      setSending(false);
    }
  }

  return (
    <form onSubmit={submit} className="mt-4 mb-3">
      <div className="flex flex-wrap gap-3">
        <input
          type="email"
          required
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          placeholder="you@example.com"
          aria-label="Email address"
          className="min-w-60 flex-1 rounded-lg border border-line-2 bg-surface-2 px-3 py-2.5 text-[14px] text-fg"
        />
        <button
          type="submit"
          disabled={sending}
          className="rounded-lg bg-accent px-4 py-2.5 font-medium text-[14px] text-accent-fg disabled:opacity-60"
        >
          {sending ? "Sending…" : "Send my key"}
        </button>
      </div>
      {message ? (
        <p className="mt-3 text-[14px] text-sage" role="status">
          {message}
        </p>
      ) : null}
    </form>
  );
}
