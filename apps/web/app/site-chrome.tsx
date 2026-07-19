export function SiteHeader() {
  return (
    <header className="sticky top-0 z-40 border-line border-b bg-[color-mix(in_oklab,var(--color-bg)_72%,transparent)] backdrop-blur-[16px]">
      <div className="mx-auto flex h-14 w-full max-w-280 items-center justify-between px-6">
        <a href="/" className="flex items-center gap-2 font-semibold text-[15px]">
          <img
            src="/app-icon-512.png"
            alt="Edith app icon"
            width="28"
            height="28"
            className="size-7 rounded-[22%] shadow-brand-icon"
          />
          <span>Edith</span>
        </a>
        <nav className="hidden gap-8 md:flex [&>a:hover]:text-fg [&>a]:text-[13px] [&>a]:text-muted">
          <a href="/#features">Features</a>
          <a href="/#performance">Performance</a>
        </nav>
        <a href="/#download" className="inline-flex cursor-pointer items-center justify-center gap-2 rounded-full border border-transparent bg-fg px-4! px-6 py-1.5! py-3 font-medium text-[13px]! text-[14px] text-bg transition-[transform_0.35s_cubic-bezier(0.16,1,0.3,1),border-color_0.35s_ease,box-shadow_0.35s_ease] hover:-translate-y-px motion-reduce:transition-none">
          Download
        </a>
      </div>
    </header>
  );
}

export function SiteFooter() {
  return (
    <footer className="border-line border-t">
      <div className="mx-auto flex w-full max-w-280 flex-col gap-6 px-6 py-10 md:flex-row md:items-center md:justify-between">
        <div className="flex items-center gap-2 font-semibold text-[15px]">
          <img
            src="/app-icon-512.png"
            alt="Edith app icon"
            width="28"
            height="28"
            className="size-7 rounded-[22%] shadow-brand-icon"
          />
          <span className="text-[12px] text-muted">Edith. Made for macOS.</span>
        </div>
        <div className="flex gap-6 text-[13px] text-muted [&>a:hover]:text-fg">
          <a href="/#features">Features</a>
          <a href="/#download">Download</a>
          <a href="/terms">Terms</a>
          <a href="/privacy">Privacy</a>
        </div>
      </div>
    </footer>
  );
}
