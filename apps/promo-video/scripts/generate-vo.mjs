import {readFileSync, writeFileSync, mkdirSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '..', '..', '..');
const outDir = join(here, '..', 'public', 'announce', 'vo');

const readEnvKey = (name) => {
  if (process.env[name]) return process.env[name];
  for (const file of ['.env', '.env.local']) {
    try {
      const text = readFileSync(join(repoRoot, file), 'utf8');
      const line = text.split('\n').find((l) => l.startsWith(`${name}=`));
      if (line) return line.slice(name.length + 1).trim().replace(/^["']|["']$/g, '');
    } catch {}
  }
  return null;
};

const apiKey = readEnvKey('ELEVENLABS_API_KEY');
if (!apiKey) {
  console.error('ELEVENLABS_API_KEY not found in env or repo root .env');
  process.exit(1);
}

const voiceId = readEnvKey('ELEVENLABS_VOICE_ID') ?? 'JBFqnCBsd6RMkjVDRZzb';

const lines = [
  ['A01', "Let's talk about what it costs to make your Mac feel complete."],
  ['A02', "Want clipboard history? That's a paste manager. Six dollars a month."],
  ['A03', "Screen dimming, for focus? That's a different app. Five more."],
  ['A04', 'A music player. A color picker. A per-app volume mixer. Each one, another subscription.'],
  ['A05', "And tracking your AI usage? That's a rate-limit tracker, a menu-bar readout, an alerts service, and an analytics dashboard."],
  ['A06', 'Add a spend heatmap. A mic muter. A disk cleaner. It never ends.'],
  ['A07', 'Twelve subscriptions. Seventy dollars a month. Forever.'],
  ['A08', 'Or... you install one app. This is Edith.'],
  ['A09', 'Edith lives in the notch. Space your Mac already has. Hover, and it opens.'],
  ['A10', 'That paste manager? Built in. With a file shelf, right at the top of your screen.'],
  ['A11', 'Your alerts appear where your eyes already are.'],
  ['A12', 'And one window brings everything together.'],
  ['A13', 'The rate-limit tracker? Replaced. Every AI agent you run, with live limits and countdowns.'],
  ['A14', 'The dashboard? Included. Every token, and every dollar, accounted for.'],
  ['A15', 'The heatmap too. A full year of usage, at a glance.'],
  ['A16', 'The menu-bar readout? Right here. One glance away.'],
  ['A17', 'The music player? Covered.'],
  ['A18', 'The focus dimmer, the sleep blocker, the disk cleaner. Handled.'],
  ['A18b', 'Oh, and when the keys need a wipe? One click turns the keyboard off. Clean away.'],
  ['A19', 'Twelve extensions. Every one of them optional.'],
  ['A19b', "And with everything packed in, you'd think Edith is heavy. Nope. It's a native Swift app. Near zero CPU, and about twenty-two megabytes of memory."],
  ['A20', 'And unlike those twelve subscriptions, nothing ever leaves your Mac. Local first. No accounts. No cloud.'],
  ['A21', 'Edith. Twelve subscriptions, replaced by one app. Early preview. Releasing soon.'],
];

mkdirSync(outDir, {recursive: true});

const only = process.argv.slice(2);
const selected = only.length ? lines.filter(([id]) => only.includes(id)) : lines;

for (const [id, text] of selected) {
  const res = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}?output_format=mp3_44100_128`,
    {
      method: 'POST',
      headers: {'xi-api-key': apiKey, 'Content-Type': 'application/json'},
      body: JSON.stringify({
        text,
        model_id: 'eleven_multilingual_v2',
        voice_settings: {stability: 0.5, similarity_boost: 0.75, style: 0.35},
      }),
    },
  );
  if (!res.ok) {
    console.error(`${id} failed: ${res.status} ${await res.text()}`);
    process.exit(1);
  }
  writeFileSync(join(outDir, `${id}.mp3`), Buffer.from(await res.arrayBuffer()));
  console.log(`${id} ok`);
}
