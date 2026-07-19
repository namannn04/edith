export function SiteHeader() {
  return (
    <header className="nav">
      <div className="page nav-inner">
        <a href="/" className="brand">
          <img
            src="/app-icon-512.png"
            alt="Edith app icon"
            width="28"
            height="28"
            className="brand-icon"
          />
          <span>Edith</span>
        </a>
        <nav className="nav-links">
          <a href="/#features">Features</a>
          <a href="/#performance">Performance</a>
        </nav>
        <a href="/#download" className="btn btn-solid btn-sm">
          Download
        </a>
      </div>
    </header>
  );
}

export function SiteFooter() {
  return (
    <footer className="footer">
      <div className="page footer-inner">
        <div className="brand">
          <img
            src="/app-icon-512.png"
            alt="Edith app icon"
            width="28"
            height="28"
            className="brand-icon"
          />
          <span className="muted small">Edith. Made for macOS.</span>
        </div>
        <div className="footer-links">
          <a href="/#features">Features</a>
          <a href="/#download">Download</a>
          <a href="/terms">Terms</a>
          <a href="/privacy">Privacy</a>
        </div>
      </div>
    </footer>
  );
}
