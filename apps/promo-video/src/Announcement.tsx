import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Img,
  Sequence,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {colors, fontFamily} from './tokens';
import {springIn} from './animation';
import {Background} from './components/Background';
import {CaptionsEnabled} from './components/Caption';
import {NotchAlertScene, NotchHeroScene, NotchTabsScene} from './announce/MacBookNotch';
import {PileupStage, ProblemHook} from './announce/PileupStory';
import {NativeScene} from './announce/NativeScene';
import {HomeDashboardScene} from './scenes/HomeDashboardScene';
import {AgentUsageRings} from './scenes/AgentUsageRings';
import {UsageStats} from './scenes/UsageStats';
import {ActivityHeatmap} from './scenes/ActivityHeatmap';
import {MenuBarBadgeScene} from './scenes/MenuBarBadgeScene';
import {MusicScene} from './scenes/MusicScene';
import {SystemScene} from './scenes/SystemScene';
import {SettingsMontage} from './scenes/SettingsMontage';
import {TrustScene} from './scenes/TrustScene';

const asset = (name: string) => staticFile(`announce/${name}`);

const FADE = 12;

const SceneFade: React.FC<{
  frames: number;
  fadeIn?: boolean;
  fadeOut?: boolean;
  children: React.ReactNode;
}> = ({frames, fadeIn = true, fadeOut = true, children}) => {
  const frame = useCurrentFrame();
  const inO = fadeIn
    ? interpolate(frame, [0, FADE], [0, 1], {
        extrapolateLeft: 'clamp',
        extrapolateRight: 'clamp',
      })
    : 1;
  const outO = fadeOut
    ? interpolate(frame, [frames - FADE, frames], [1, 0], {
        extrapolateLeft: 'clamp',
        extrapolateRight: 'clamp',
      })
    : 1;
  return <AbsoluteFill style={{opacity: Math.min(inO, outO)}}>{children}</AbsoluteFill>;
};

const ColdOpen: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const icon = springIn(frame, fps, 6);
  const title = springIn(frame, fps, 22);
  const sub = springIn(frame, fps, 40);
  return (
    <Background>
      <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', fontFamily}}>
        <Img
          src={staticFile('logo.png')}
          style={{
            width: 148,
            height: 148,
            borderRadius: 34,
            opacity: icon,
            transform: `scale(${interpolate(icon, [0, 1], [0.85, 1])})`,
            filter: 'drop-shadow(0 24px 60px rgba(245,166,35,0.25))',
          }}
        />
        <div
          style={{
            marginTop: 38,
            fontSize: 76,
            fontWeight: 700,
            letterSpacing: -1.5,
            color: colors.text,
            opacity: title,
            transform: `translateY(${interpolate(title, [0, 1], [16, 0])}px)`,
          }}
        >
          Edith
        </div>
        <div
          style={{
            marginTop: 14,
            fontSize: 30,
            color: colors.textDim,
            opacity: sub,
            transform: `translateY(${interpolate(sub, [0, 1], [14, 0])}px)`,
          }}
        >
          A quiet control center for your Mac.
        </div>
      </div>
    </Background>
  );
};

const AnnouncementOutro: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const icon = springIn(frame, fps, 6);
  const name = springIn(frame, fps, 20);
  const tag = springIn(frame, fps, 38);
  const url = springIn(frame, fps, 58);
  return (
    <Background>
      <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', fontFamily}}>
        <Img
          src={staticFile('logo.png')}
          style={{width: 128, height: 128, borderRadius: 30, opacity: icon}}
        />
        <div
          style={{
            marginTop: 30,
            fontSize: 64,
            fontWeight: 700,
            letterSpacing: -1.2,
            color: colors.text,
            opacity: name,
          }}
        >
          Edith
        </div>
        <div style={{marginTop: 12, fontSize: 28, color: colors.textDim, opacity: tag}}>
          One app instead of twelve subscriptions.
        </div>
        <div
          style={{
            marginTop: 34,
            fontSize: 26,
            fontWeight: 600,
            color: colors.accent,
            opacity: url,
            padding: '14px 34px',
            borderRadius: 999,
            border: `1px solid ${colors.accentSoft}`,
            background: colors.accentSoft,
          }}
        >
          Early preview · releasing soon
        </div>
      </div>
    </Background>
  );
};

const SCENES: Array<{
  id: string;
  frames: number;
  vo?: string;
  voSeconds?: number;
  subs?: string[];
  vo2?: string;
  vo2At?: number;
  vo2Seconds?: number;
  subs2?: string[];
  fadeIn?: boolean;
  fadeOut?: boolean;
  node: React.ReactNode;
}> = [
  {
    id: 'hook',
    frames: 135,
    vo: 'A01.mp3',
    voSeconds: 3.48,
    subs: ["Let's talk about what it costs", 'to make your Mac feel *complete*.'],
    node: <ProblemHook />,
  },
  {
    id: 'p1',
    frames: 145,
    vo: 'A02.mp3',
    voSeconds: 3.58,
    subs: ['Want *clipboard history*?', "That's a paste manager. *Six dollars* a month."],
    fadeOut: false,
    node: <PileupStage revealFrom={0} revealTo={1} />,
  },
  {
    id: 'p2',
    frames: 125,
    vo: 'A03.mp3',
    voSeconds: 3.11,
    subs: ['*Screen dimming*, for focus?', "That's a different app. *Five* more."],
    fadeIn: false,
    fadeOut: false,
    node: <PileupStage revealFrom={1} revealTo={2} />,
  },
  {
    id: 'p3',
    frames: 180,
    vo: 'A04.mp3',
    voSeconds: 4.92,
    subs: [
      'A *music player*. A *color picker*. A *volume mixer*.',
      'Each one, another subscription.',
    ],
    fadeIn: false,
    fadeOut: false,
    node: <PileupStage revealFrom={2} revealTo={5} />,
  },
  {
    id: 'p4',
    frames: 295,
    vo: 'A05.mp3',
    voSeconds: 8.96,
    subs: [
      'And tracking your *AI usage*?',
      'A *rate-limit tracker*. A menu-bar *readout*.',
      'An *alerts service*. And an analytics *dashboard*.',
    ],
    fadeIn: false,
    fadeOut: false,
    node: <PileupStage revealFrom={5} revealTo={9} />,
  },
  {
    id: 'p5',
    frames: 160,
    vo: 'A06.mp3',
    voSeconds: 4.23,
    subs: ['Add a *heatmap*. A *mic muter*. A *disk cleaner*.', 'It never ends.'],
    fadeIn: false,
    fadeOut: false,
    node: <PileupStage revealFrom={9} revealTo={12} />,
  },
  {
    id: 'p6',
    frames: 160,
    vo: 'A07.mp3',
    voSeconds: 2.88,
    subs: ['*Twelve* subscriptions. *Seventy dollars* a month.', '*Forever*.'],
    fadeIn: false,
    fadeOut: false,
    node: <PileupStage revealFrom={12} revealTo={12} showTotal collapse />,
  },
  {
    id: 'turn',
    frames: 125,
    vo: 'A08.mp3',
    voSeconds: 2.51,
    subs: ['Or, you install *one app*.', 'This is *Edith*.'],
    node: <ColdOpen />,
  },
  {
    id: 'notchHero',
    frames: 240,
    vo: 'A09.mp3',
    voSeconds: 4.37,
    subs: ['Edith lives in the *notch*. Space your Mac already has.', '*Hover*, and it opens.'],
    node: <NotchHeroScene />,
  },
  {
    id: 'notchTabs',
    frames: 200,
    vo: 'A10.mp3',
    voSeconds: 3.99,
    subs: [
      'That *paste manager*? Built in.',
      'With a *file shelf*, right at the top of your screen.',
    ],
    node: <NotchTabsScene />,
  },
  {
    id: 'alert',
    frames: 120,
    vo: 'A11.mp3',
    voSeconds: 2.41,
    subs: ['Your *alerts* appear where your *eyes* already are.'],
    node: <NotchAlertScene />,
  },
  {
    id: 'home',
    frames: 110,
    vo: 'A12.mp3',
    voSeconds: 2.23,
    subs: ['And *one window* brings everything together.'],
    node: <HomeDashboardScene />,
  },
  {
    id: 'rings',
    frames: 210,
    vo: 'A13.mp3',
    voSeconds: 5.99,
    subs: [
      'The *rate-limit tracker*? Replaced.',
      'Every *AI agent* you run, with *live limits* and countdowns.',
    ],
    node: <AgentUsageRings />,
  },
  {
    id: 'stats',
    frames: 150,
    vo: 'A14.mp3',
    voSeconds: 3.81,
    subs: ['The *dashboard*? Included.', 'Every *token*, and every *dollar*, accounted for.'],
    node: <UsageStats />,
  },
  {
    id: 'heatmap',
    frames: 125,
    vo: 'A15.mp3',
    voSeconds: 3.16,
    subs: ['The *heatmap* too. A *full year* of usage, at a glance.'],
    node: <ActivityHeatmap />,
  },
  {
    id: 'menubar',
    frames: 120,
    vo: 'A16.mp3',
    voSeconds: 2.79,
    subs: ['The *menu-bar readout*? Right here. *One glance* away.'],
    node: <MenuBarBadgeScene />,
  },
  {
    id: 'music',
    frames: 110,
    vo: 'A17.mp3',
    voSeconds: 1.44,
    subs: ['The *music player*? Covered.'],
    node: <MusicScene />,
  },
  {
    id: 'system',
    frames: 285,
    vo: 'A18.mp3',
    voSeconds: 3.62,
    subs: ['The *focus dimmer*, the *sleep blocker*, the *disk cleaner*.', '*Handled*.'],
    vo2: 'A18b.mp3',
    vo2At: 135,
    vo2Seconds: 3.85,
    subs2: ['Oh, and when the keys need a *wipe*?', 'One click turns the *keyboard off*. Clean away.'],
    node: <SystemScene />,
  },
  {
    id: 'settings',
    frames: 125,
    vo: 'A19.mp3',
    voSeconds: 2.65,
    subs: ['*Twelve extensions*. Every one of them optional.'],
    node: <SettingsMontage />,
  },
  {
    id: 'light',
    frames: 340,
    vo: 'A19b.mp3',
    voSeconds: 10.4,
    subs: [
      'With everything packed in,',
      "you'd think Edith is *heavy*. Nope.",
      "It's a *native Swift* app.",
      '*Near zero* CPU. About *22 megabytes* of memory.',
    ],
    node: <NativeScene />,
  },
  {
    id: 'trust',
    frames: 260,
    vo: 'A20.mp3',
    voSeconds: 7.8,
    subs: [
      'And unlike those twelve subscriptions,',
      'nothing ever *leaves your Mac*.',
      '*Local first*. No accounts. No cloud.',
    ],
    node: <TrustScene />,
  },
  {
    id: 'outro',
    frames: 190,
    vo: 'A21.mp3',
    voSeconds: 4.37,
    subs: ['*Edith*. Twelve subscriptions, replaced by *one app*.', '*Early preview*. Releasing soon.'],
    node: <AnnouncementOutro />,
  },
];

const subtitleFont =
  '"Futura-CondensedExtraBold", "Avenir Next Condensed", "Arial Narrow", ' + fontFamily;

const plain = (text: string) => text.replace(/\*/g, '');

const parseWords = (text: string) => {
  const words: Array<{text: string; hl: boolean}> = [];
  for (const part of text.split(/(\*[^*]+\*)/)) {
    const hl = part.startsWith('*');
    const clean = hl ? part.slice(1, -1) : part;
    for (const w of clean.split(' ')) {
      if (!w) continue;
      if (/^[.,!?;:]+$/.test(w) && words.length > 0) {
        words[words.length - 1].text += w;
      } else {
        words.push({text: w, hl});
      }
    }
  }
  return words;
};

const KaraokeText: React.FC<{text: string; progress: number}> = ({text, progress}) => {
  const words = parseWords(text);
  const spoken = progress * words.length;
  return (
    <>
      {words.map((w, i) => {
        const wordP = Math.min(1, Math.max(0, spoken - i));
        const off = 'rgba(34,30,25,0.22)';
        const on = w.hl ? colors.accent : '#221e19';
        return (
          <React.Fragment key={i}>
            <span style={{color: wordP > 0.5 ? on : off}}>{w.text}</span>
            {i < words.length - 1 ? ' ' : null}
          </React.Fragment>
        );
      })}
    </>
  );
};

const Subtitles: React.FC<{chunks: string[]; voSeconds: number}> = ({chunks, voSeconds}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const totalWords = chunks.reduce((a, c) => a + plain(c).split(' ').length, 0);
  const voFrames = voSeconds * fps;
  let cursor = 0;
  let active: {text: string; from: number; to: number} | null = null;
  for (const chunk of chunks) {
    const share = plain(chunk).split(' ').length / totalWords;
    const from = cursor;
    const to = cursor + share * voFrames;
    if (frame >= from && frame < to + 8) {
      active = {text: chunk, from, to};
      break;
    }
    cursor = to;
  }
  if (!active) return null;
  const pop = springIn(frame, fps, active.from);
  const opacity = interpolate(
    frame,
    [active.from, active.from + 4, active.to + 4, active.to + 8],
    [0, 1, 1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  return (
    <div
      style={{
        position: 'absolute',
        bottom: 44,
        left: 0,
        right: 0,
        display: 'flex',
        justifyContent: 'center',
        opacity,
        zIndex: 90,
      }}
    >
      <div
        style={{
          maxWidth: 1500,
          background: '#faf8f4',
          borderRadius: 16,
          padding: '10px 30px 12px',
          fontFamily: subtitleFont,
          fontSize: 44,
          fontWeight: 900,
          letterSpacing: 0.5,
          textTransform: 'uppercase',
          color: '#221e19',
          textAlign: 'center',
          lineHeight: 1.2,
          boxShadow: '0 14px 40px rgba(0,0,0,0.45)',
          transform: `scale(${interpolate(pop, [0, 1], [0.92, 1])})`,
        }}
      >
        <KaraokeText
          text={active.text}
          progress={interpolate(frame, [active.from, active.to], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          })}
        />
      </div>
    </div>
  );
};

export const announcementDuration = SCENES.reduce((a, s) => a + s.frames, 0);

export const Announcement: React.FC = () => {
  let at = 0;
  return (
    <CaptionsEnabled.Provider value={false}>
      <AbsoluteFill style={{background: colors.bg}}>
        <Audio src={asset('music-bed.m4a')} volume={0.9} />
        {SCENES.map((s) => {
          const from = at;
          at += s.frames;
          return (
            <Sequence key={s.id} from={from} durationInFrames={s.frames}>
              {s.vo ? <Audio src={asset(`vo/${s.vo}`)} /> : null}
              <SceneFade frames={s.frames} fadeIn={s.fadeIn} fadeOut={s.fadeOut}>
                {s.node}
              </SceneFade>
              {s.subs && s.voSeconds ? (
                <Subtitles chunks={s.subs} voSeconds={s.voSeconds} />
              ) : null}
              {s.vo2 && s.vo2At != null ? (
                <Sequence from={s.vo2At} durationInFrames={s.frames - s.vo2At}>
                  <Audio src={asset(`vo/${s.vo2}`)} />
                  {s.subs2 && s.vo2Seconds ? (
                    <Subtitles chunks={s.subs2} voSeconds={s.vo2Seconds} />
                  ) : null}
                </Sequence>
              ) : null}
            </Sequence>
          );
        })}
      </AbsoluteFill>
    </CaptionsEnabled.Provider>
  );
};
