const features = [
  {
    title: "Extension marketplace",
    detail: "Add only the tools that belong in your day.",
  },
  {
    title: "Permissions when needed",
    detail: "Edith asks at the moment a feature needs access.",
  },
  {
    title: "Silent updates",
    detail: "Stay current without breaking your flow.",
  },
];

export default function HomePage() {
  return (
    <main className="site-shell">
      <section className="hero" aria-labelledby="edith-title">
        <div className="quiet-bar" aria-hidden="true">
          <span className="quiet-bar__mark" />
          <span className="quiet-bar__pulse" />
        </div>
        <p className="eyebrow">A quiet place for busy things</p>
        <h1 id="edith-title">Edith</h1>
        <p className="pitch">
          your Mac&apos;s quiet copilot: agent usage, music, clipboard, and a
          smarter notch
        </p>
        <a className="download-button" href="/api/v1/download/installer">
          Download for macOS
          <span aria-hidden="true">↓</span>
        </a>
        <p className="compatibility">Built for Apple silicon</p>
      </section>

      <section className="feature-strip" aria-label="Edith features">
        {features.map((feature) => (
          <article className="feature" key={feature.title}>
            <span className="feature__signal" aria-hidden="true" />
            <h2>{feature.title}</h2>
            <p>{feature.detail}</p>
          </article>
        ))}
      </section>

      <footer className="footer">
        <a href="https://pulkit.page">Made by Pulkit</a>
        <a href="/license">License</a>
      </footer>
    </main>
  );
}
