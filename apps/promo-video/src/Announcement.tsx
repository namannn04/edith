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

const SceneFade: React.FC<{frames: number; children: React.ReactNode}> = ({
  frames,
  children,
}) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, FADE, frames - FADE, frames], [0, 1, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return <AbsoluteFill style={{opacity}}>{children}</AbsoluteFill>;
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
          edith.app · $50, one time
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
  node: React.ReactNode;
}> = [
  {
    id: 'cold',
    frames: 165,
    vo: 'L01.mp3',
    voSeconds: 3.58,
    subs: ['This is *Edith*. A quiet control center for your *Mac*.'],
    node: <ColdOpen />,
  },
  {
    id: 'notchHero',
    frames: 240,
    vo: 'L02.mp3',
    voSeconds: 4.41,
    subs: ['It lives where your Mac already has *room*.', '*Hover* the notch, and it opens.'],
    node: <NotchHeroScene />,
  },
  {
    id: 'notchTabs',
    frames: 200,
    vo: 'L03.mp3',
    voSeconds: 5.11,
    subs: [
      'Park files on a *shelf*. Reach your clipboard *history*.',
      'Right from the *top* of your screen.',
    ],
    node: <NotchTabsScene />,
  },
  {
    id: 'alert',
    frames: 120,
    vo: 'L04.mp3',
    voSeconds: 2.37,
    subs: ['Alerts appear where your *eyes* already are.'],
    node: <NotchAlertScene />,
  },
  {
    id: 'home',
    frames: 110,
    vo: 'L05.mp3',
    voSeconds: 1.86,
    subs: ['*One window* brings it all together.'],
    node: <HomeDashboardScene />,
  },
  {
    id: 'rings',
    frames: 180,
    vo: 'L06.mp3',
    voSeconds: 4.6,
    subs: ['Track *every AI agent* you run,', 'with *live rate limits* and countdowns.'],
    node: <AgentUsageRings />,
  },
  {
    id: 'stats',
    frames: 140,
    vo: 'L06b.mp3',
    voSeconds: 3.72,
    subs: ['See exactly where every *token* and every *dollar* went.'],
    node: <UsageStats />,
  },
  {
    id: 'heatmap',
    frames: 110,
    vo: 'L06c.mp3',
    voSeconds: 2.37,
    subs: ['And a *full year* of usage, at a glance.'],
    node: <ActivityHeatmap />,
  },
  {
    id: 'menubar',
    frames: 130,
    vo: 'L07.mp3',
    voSeconds: 3.16,
    subs: ['Your limits stay *one glance* away,', 'right in the *menu bar*.'],
    node: <MenuBarBadgeScene />,
  },
  {
    id: 'music',
    frames: 110,
    vo: 'L08.mp3',
    voSeconds: 2.23,
    subs: ['Your *local music*, played beautifully.'],
    node: <MusicScene />,
  },
  {
    id: 'system',
    frames: 270,
    vo: 'L09.mp3',
    voSeconds: 3.34,
    subs: ['Runaway apps. Junk. Sleep. *Handled*.'],
    node: <SystemScene />,
  },
  {
    id: 'settings',
    frames: 125,
    vo: 'L10.mp3',
    voSeconds: 3.02,
    subs: ['*Twelve extensions*. Every one of them optional.'],
    node: <SettingsMontage />,
  },
  {
    id: 'trust',
    frames: 185,
    vo: 'L11.mp3',
    voSeconds: 5.11,
    subs: ['And everything *stays on your Mac*.', '*Local first*. No accounts. No subscriptions.'],
    node: <TrustScene />,
  },
  {
    id: 'outro',
    frames: 190,
    vo: 'L12.mp3',
    voSeconds: 5.02,
    subs: ['*Edith*. One app instead of twelve subscriptions.', '*Pay once*. Own it forever.'],
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
              <SceneFade frames={s.frames}>{s.node}</SceneFade>
              {s.subs && s.voSeconds ? (
                <Subtitles chunks={s.subs} voSeconds={s.voSeconds} />
              ) : null}
            </Sequence>
          );
        })}
      </AbsoluteFill>
    </CaptionsEnabled.Provider>
  );
};
