import { ymd, MON } from "./format.js";

// ---------- billing-cycle date math (pure; no DOM, no state) ----------
// A cycle anchored on day D starts on day D of a month and ends the day before
// day D of the next month. Months shorter than D clamp to their last day
// (e.g. D=31 in February -> the 28th/29th).

const daysInMonth = (y, m) => new Date(y, m + 1, 0).getDate(); // m is 0-based
const anchorFor = (y, m, day) =>
  new Date(y, m, Math.min(day, daysInMonth(y, m)));

// Start (a Date at local midnight) of the cycle that contains `date`.
export function cycleStart(date, day) {
  const y = date.getFullYear(),
    m = date.getMonth();
  const anchor = Math.min(day, daysInMonth(y, m));
  if (date.getDate() >= anchor) return new Date(y, m, anchor);
  return anchorFor(m === 0 ? y - 1 : y, m === 0 ? 11 : m - 1, day);
}

// Inclusive end (a Date) of the cycle that starts at `start`: day before the
// next anchor.
export function cycleEnd(start, day) {
  const y = start.getFullYear(),
    m = start.getMonth();
  const next = anchorFor(m === 11 ? y + 1 : y, m === 11 ? 0 : m + 1, day);
  const end = new Date(next);
  end.setDate(end.getDate() - 1);
  return end;
}

// "26 May – 25 Jun 2026"; the start's year is shown only when it differs from the end's.
function label(start, end) {
  const s =
    `${start.getDate()} ${MON[start.getMonth()]}` +
    (start.getFullYear() !== end.getFullYear()
      ? ` ${start.getFullYear()}`
      : "");
  return `${s} – ${end.getDate()} ${MON[end.getMonth()]} ${end.getFullYear()}`;
}

// Every cycle overlapping [earliest, latest], newest first:
// [{ start:"YYYY-MM-DD", end:"YYYY-MM-DD", label }]
export function cyclesFromBounds(earliest, latest, day) {
  const out = [];
  let start = cycleStart(earliest, day);
  while (start <= latest) {
    const end = cycleEnd(start, day);
    out.push({ start: ymd(start), end: ymd(end), label: label(start, end) });
    start = new Date(end);
    start.setDate(start.getDate() + 1);
  }
  return out.reverse();
}
