"use client";

import { useEffect } from "react";

const tracks = [
  {
    title: "Weightless",
    artist: "Marconi Union",
    from: "var(--color-art-coral)",
    to: "var(--color-art-rust)",
  },
  {
    title: "Nightcall",
    artist: "Kavinsky",
    from: "var(--color-art-blue)",
    to: "var(--color-art-navy)",
  },
  {
    title: "Strobe",
    artist: "deadmau5",
    from: "var(--color-art-green)",
    to: "var(--color-art-forest)",
  },
  {
    title: "Teardrop",
    artist: "Massive Attack",
    from: "var(--color-art-purple)",
    to: "var(--color-art-plum)",
  },
  {
    title: "Intro",
    artist: "The xx",
    from: "var(--color-track-gold)",
    to: "var(--color-track-ochre)",
  },
];

const heatmapCellClasses = [
  "block aspect-square rounded-[3px] bg-warm-5",
  "block aspect-square rounded-[3px] bg-accent/[28%]",
  "block aspect-square rounded-[3px] bg-accent/[50%]",
  "block aspect-square rounded-[3px] bg-accent/[72%]",
  "block aspect-square rounded-[3px] bg-accent",
];

function level(index: number) {
  const random = Math.abs(Math.sin(index * 12.9898 + 4.1) * 43758.5453) % 1;
  return random < 0.06 ? 0 : Math.min(4, 1 + Math.floor(random * 4.2));
}

export default function LandingBehavior() {
  useEffect(() => {
    const generatedElements: HTMLElement[] = [];
    const intervals: number[] = [];

    document
      .querySelectorAll<HTMLElement>("[data-rows][data-cols]")
      .forEach((element) => {
        const rows = Number(element.dataset.rows) || 7;
        const columns = Number(element.dataset.cols) || 16;
        const fragment = document.createDocumentFragment();
        for (let column = 0; column < columns; column += 1) {
          for (let row = 0; row < rows; row += 1) {
            const cell = document.createElement("i");
            cell.className = heatmapCellClasses[level(column * rows + row)];
            generatedElements.push(cell);
            fragment.appendChild(cell);
          }
        }
        element.appendChild(fragment);
      });

    document
      .querySelectorAll<HTMLElement>("[data-spark]")
      .forEach((element) => {
        const heights = [
          18, 22, 20, 26, 30, 28, 34, 40, 37, 44, 48, 46, 53, 58, 55, 61, 66,
          64, 68,
        ];
        for (const height of heights) {
          const bar = document.createElement("i");
          bar.className = "block flex-1 rounded-[2px] bg-accent/[55%]";
          bar.style.height = `${height}%`;
          generatedElements.push(bar);
          element.appendChild(bar);
        }
      });

    const titleElement = document.querySelector<HTMLElement>("[data-title]");
    const artistElement = document.querySelector<HTMLElement>("[data-artist]");
    const artElement = document.querySelector<HTMLElement>("[data-art]");
    const progressElement =
      document.querySelector<HTMLElement>("[data-progress]");
    if (titleElement && artistElement && artElement && progressElement) {
      let trackIndex = 0;
      let progress = 18;
      const paint = () => {
        const track = tracks[trackIndex];
        titleElement.textContent = track.title;
        artistElement.textContent = track.artist;
        artElement.style.background = `linear-gradient(145deg, ${track.from}, ${track.to})`;
      };
      paint();
      intervals.push(
        window.setInterval(() => {
          progress += 100 / 60;
          if (progress >= 100) {
            progress = 0;
            trackIndex = (trackIndex + 1) % tracks.length;
            paint();
          }
          progressElement.style.width = `${progress}%`;
        }, 100),
      );
    }

    const revealTargets = document.querySelectorAll<HTMLElement>(
      "[data-reveal-item], [data-reveal-group] > *",
    );
    let observer: IntersectionObserver | undefined;
    if ("IntersectionObserver" in window && revealTargets.length) {
      const groups = new Map<HTMLElement | null, number>();
      revealTargets.forEach((element) => {
        const parent = element.parentElement;
        const index = groups.get(parent) ?? 0;
        groups.set(parent, index + 1);
        element.dataset.reveal = "pending";
        element.style.setProperty(
          "--reveal-delay",
          `${Math.min(index * 0.07, 0.42)}s`,
        );
      });
      observer = new IntersectionObserver(
        (entries) => {
          for (const entry of entries) {
            if (entry.isIntersecting) {
              (entry.target as HTMLElement).dataset.reveal = "visible";
              observer?.unobserve(entry.target);
            }
          }
        },
        { rootMargin: "0px 0px -8% 0px", threshold: 0.15 },
      );
      for (const element of revealTargets) {
        observer.observe(element);
      }
    }

    const presenterDemo = document.querySelector<HTMLElement>(
      "[data-presenter-demo]",
    );
    if (presenterDemo) {
      const badge = presenterDemo.querySelector<HTMLElement>("[data-pbadge]");
      const note = presenterDemo.querySelector<HTMLElement>("[data-pnote]");
      if (badge && note) {
        const flip = () => {
          const enabled = presenterDemo.dataset.presenterState !== "on";
          presenterDemo.dataset.presenterState = enabled ? "on" : "off";
          badge.textContent = enabled ? "Presenter on" : "Presenter off";
          badge.style.opacity = enabled ? "1" : "0.5";
          note.textContent = enabled
            ? "Spend and track names hidden for the room."
            : "Everything visible to you.";
        };
        presenterDemo.dataset.presenterState = "off";
        flip();
        intervals.push(window.setInterval(flip, 2200));
      }
    }

    return () => {
      for (const interval of intervals) {
        window.clearInterval(interval);
      }
      observer?.disconnect();
      for (const element of generatedElements) {
        element.remove();
      }
    };
  }, []);

  return null;
}
