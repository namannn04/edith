export interface FrontMatter {
  date: Date | null;
  title: string | null;
}

const dateKeys = new Set(["date", "created", "occurred_at"]);

function scalar(value: string): string {
  const trimmed = value.trim();
  const quote = trimmed[0];

  if (
    trimmed.length >= 2 &&
    (quote === '"' || quote === "'") &&
    trimmed.at(-1) === quote
  ) {
    return trimmed.slice(1, -1).trim();
  }

  return trimmed;
}

function parsedDate(value: string): Date | null {
  const normalized = /^\d{4}-\d{2}-\d{2}$/.test(value)
    ? `${value}T00:00:00.000Z`
    : value;
  const date = new Date(normalized);
  return Number.isNaN(date.getTime()) ? null : date;
}

export function parseFrontMatter(text: string): FrontMatter {
  const lines = text.split(/\r?\n/);
  let bodyStart = 0;
  let date: Date | null = null;
  let title: string | null = null;

  if (lines[0]?.trim() === "---") {
    const closingIndex = lines.findIndex(
      (line, index) => index > 0 && line.trim() === "---",
    );

    if (closingIndex > 0) {
      bodyStart = closingIndex + 1;

      for (const line of lines.slice(1, closingIndex)) {
        const separator = line.indexOf(":");
        if (separator < 1) {
          continue;
        }

        const key = line.slice(0, separator).trim();
        const value = scalar(line.slice(separator + 1));

        if (key === "title" && value) {
          title = value;
        }

        if (date === null && dateKeys.has(key) && value) {
          date = parsedDate(value);
        }
      }
    }
  }

  if (title === null) {
    const heading = lines
      .slice(bodyStart)
      .find((line) => line.startsWith("# "))
      ?.slice(2)
      .trim();
    title = heading || null;
  }

  return { date, title };
}
