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
import {colors, fontFamily, fps} from './tokens';
import {easeOut, springIn} from './animation';

const asset = (name: string) => staticFile(`announce/${name}`);

const SCENES = [
  {id: 'cold', frames: 150, vo: 'L01.mp3'},
  {id: 'notchIntro', frames: 140, vo: 'L02.mp3'},
  {id: 'shelfTabs', frames: 195, vo: 'L03.mp3'},
  {id: 'alert', frames: 105, vo: 'L04.mp3'},
  {id: 'home', frames: 110, vo: 'L05.mp3'},
  {id: 'dashboard', frames: 250, vo: 'L06.mp3'},
  {id: 'menubar', frames: 130, vo: 'L07.mp3'},
  {id: 'music', frames: 110, vo: 'L08.mp3'},
  {id: 'system', frames: 110, vo: 'L09.mp3'},
  {id: 'extensions', frames: 125, vo: 'L10.mp3'},
  {id: 'trust', frames: 170, vo: 'L11.mp3'},
  {id: 'outro', frames: 190, vo: 'L12.mp3'},
] as const;

export const announcementDuration = SCENES.reduce((a, s) => a + s.frames, 0);

const sceneStart = (id: (typeof SCENES)[number]['id']) => {
  let at = 0;
  for (const s of SCENES) {
    if (s.id === id) return at;
    at += s.frames;
  }
  return at;
};

const FADE = 14;

const useSceneFade = (frames: number) => {
  const frame = useCurrentFrame();
  return interpolate(frame, [0, FADE, frames - FADE, frames], [0, 1, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
};

const Backdrop: React.FC = () => (
  <AbsoluteFill style={{background: colors.bgVignette}} />
);

const Caption: React.FC<{text: string; delay?: number}> = ({text, delay = 10}) => {
  const frame = useCurrentFrame();
  const {fps: f} = useVideoConfig();
  const p = springIn(frame, f, delay);
  return (
    <div
      style={{
        position: 'absolute',
        bottom: 64,
        width: '100%',
        textAlign: 'center',
        fontFamily,
        fontSize: 34,
        fontWeight: 500,
        letterSpacing: 0.2,
        color: colors.text,
        opacity: interpolate(p, [0, 1], [0, 0.95]),
        transform: `translateY(${interpolate(p, [0, 1], [18, 0])}px)`,
        textShadow: '0 2px 24px rgba(0,0,0,0.8)',
      }}
    >
      {text}
    </div>
  );
};

const WindowShot: React.FC<{
  src: string;
  frames: number;
  zoomFrom?: number;
  zoomTo?: number;
  originY?: string;
  panY?: [number, number];
}> = ({src, frames, zoomFrom = 1.0, zoomTo = 1.05, originY = '30%', panY}) => {
  const frame = useCurrentFrame();
  const zoom = interpolate(frame, [0, frames], [zoomFrom, zoomTo], {
    easing: easeOut,
  });
  const ty = panY
    ? interpolate(frame, [0, frames], panY, {easing: easeOut})
    : 0;
  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center'}}>
      <div
        style={{
          width: 1560,
          borderRadius: 18,
          overflow: 'hidden',
          boxShadow: '0 40px 120px rgba(0,0,0,0.65), 0 0 0 1px rgba(255,255,255,0.07)',
          transform: `translateY(${ty}px) scale(${zoom})`,
          transformOrigin: `50% ${originY}`,
        }}
      >
        <Img src={asset(src)} style={{width: '100%', display: 'block'}} />
      </div>
    </AbsoluteFill>
  );
};

const ColdOpen: React.FC<{frames: number}> = ({frames}) => {
  const frame = useCurrentFrame();
  const {fps: f} = useVideoConfig();
  const icon = springIn(frame, f, 6);
  const title = springIn(frame, f, 22);
  const sub = springIn(frame, f, 40);
  return (
    <AbsoluteFill
      style={{
        alignItems: 'center',
        justifyContent: 'center',
        fontFamily,
        opacity: useSceneFade(frames),
      }}
    >
      <Img
        src={staticFile('logo.png')}
        style={{
          width: 148,
          height: 148,
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
          fontWeight: 400,
          color: colors.textDim,
          opacity: sub,
          transform: `translateY(${interpolate(sub, [0, 1], [14, 0])}px)`,
        }}
      >
        A quiet control center for your Mac.
      </div>
    </AbsoluteFill>
  );
};

const NotchIntro: React.FC<{frames: number}> = ({frames}) => {
  const frame = useCurrentFrame();
  const stripOpacity = interpolate(frame, [0, 12, 55, 70], [0, 1, 1, 0], {
    extrapolateRight: 'clamp',
  });
  const shelfOpacity = interpolate(frame, [58, 76], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const shelfScale = interpolate(frame, [58, frames], [0.96, 1.01], {
    easing: easeOut,
  });
  const stripScale = interpolate(frame, [0, 70], [1.35, 1.62], {easing: easeOut});
  return (
    <AbsoluteFill style={{alignItems: 'center', opacity: useSceneFade(frames), fontFamily}}>
      <div style={{position: 'absolute', top: 150, opacity: stripOpacity}}>
        <Img
          src={asset('notch-strip.png')}
          style={{width: 620, transform: `scale(${stripScale})`, transformOrigin: '50% 0%'}}
        />
      </div>
      <div style={{position: 'absolute', top: 96, opacity: shelfOpacity}}>
        <Img
          src={asset('notch-home.png')}
          style={{
            width: 1180,
            transform: `scale(${shelfScale})`,
            transformOrigin: '50% 0%',
            filter: 'drop-shadow(0 40px 90px rgba(0,0,0,0.7))',
          }}
        />
      </div>
      <Caption text="It lives around the notch." delay={16} />
    </AbsoluteFill>
  );
};

const ShelfTabs: React.FC<{frames: number}> = ({frames}) => {
  const frame = useCurrentFrame();
  const cut = 96;
  const filesOpacity = interpolate(frame, [0, 10, cut - 8, cut], [0, 1, 1, 0], {
    extrapolateRight: 'clamp',
  });
  const clipOpacity = interpolate(frame, [cut, cut + 10], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const drift = interpolate(frame, [0, frames], [0, 10], {easing: easeOut});
  return (
    <AbsoluteFill style={{alignItems: 'center', opacity: useSceneFade(frames), fontFamily}}>
      <div style={{position: 'absolute', top: 90, opacity: filesOpacity}}>
        <Img
          src={asset('notch-files.png')}
          style={{
            width: 1180,
            transform: `translateY(${drift}px)`,
            filter: 'drop-shadow(0 40px 90px rgba(0,0,0,0.7))',
          }}
        />
      </div>
      <div style={{position: 'absolute', top: 76, opacity: clipOpacity}}>
        <Img
          src={asset('notch-clipboard.png')}
          style={{
            width: 1180,
            transform: `translateY(${drift}px)`,
            filter: 'drop-shadow(0 40px 90px rgba(0,0,0,0.7))',
          }}
        />
      </div>
      <Caption text="A shelf for files. A memory for your clipboard." delay={14} />
    </AbsoluteFill>
  );
};

const AlertScene: React.FC<{frames: number}> = ({frames}) => {
  const frame = useCurrentFrame();
  const {fps: f} = useVideoConfig();
  const drop = springIn(frame, f, 6, true);
  return (
    <AbsoluteFill style={{alignItems: 'center', opacity: useSceneFade(frames), fontFamily}}>
      <div
        style={{
          position: 'absolute',
          top: 120,
          opacity: drop,
          transform: `translateY(${interpolate(drop, [0, 1], [-70, 0])}px) scale(1.55)`,
          transformOrigin: '50% 0%',
        }}
      >
        <Img
          src={asset('notch-alert.png')}
          style={{width: 620, filter: 'drop-shadow(0 40px 80px rgba(0,0,0,0.7))'}}
        />
      </div>
      <Caption text="Alerts, where your eyes already are." delay={14} />
    </AbsoluteFill>
  );
};

const DashboardScene: React.FC<{frames: number}> = ({frames}) => {
  const frame = useCurrentFrame();
  const shots: Array<{src: string; from: number; to: number; panY: [number, number]}> = [
    {src: 'dash-top.jpg', from: 0, to: 92, panY: [0, -14]},
    {src: 'dash-mid.jpg', from: 92, to: 152, panY: [8, -8]},
    {src: 'dash-charts.jpg', from: 152, to: 202, panY: [8, -8]},
    {src: 'dash-projects.jpg', from: 202, to: frames, panY: [8, -10]},
  ];
  return (
    <AbsoluteFill style={{opacity: useSceneFade(frames), fontFamily}}>
      {shots.map((s) => {
        const local = frame - s.from;
        const dur = s.to - s.from;
        const opacity = interpolate(
          frame,
          [s.from, s.from + 10, s.to - 10, s.to],
          [s.from === 0 ? 1 : 0, 1, 1, s.to === frames ? 1 : 0],
          {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
        );
        if (frame < s.from - 15 || frame > s.to + 15) return null;
        const zoom = interpolate(local, [0, dur], [1.02, 1.06], {easing: easeOut});
        const ty = interpolate(local, [0, dur], s.panY, {easing: easeOut});
        return (
          <AbsoluteFill
            key={s.src}
            style={{alignItems: 'center', justifyContent: 'center', opacity}}
          >
            <div
              style={{
                width: 1600,
                borderRadius: 18,
                overflow: 'hidden',
                boxShadow: '0 40px 120px rgba(0,0,0,0.65), 0 0 0 1px rgba(255,255,255,0.07)',
                transform: `translateY(${ty}px) scale(${zoom})`,
                transformOrigin: '50% 35%',
              }}
            >
              <Img src={asset(s.src)} style={{width: '100%', display: 'block'}} />
            </div>
          </AbsoluteFill>
        );
      })}
      <Caption text="Every token. Every model. Every project." delay={12} />
    </AbsoluteFill>
  );
};

const MenubarScene: React.FC<{frames: number}> = ({frames}) => {
  const frame = useCurrentFrame();
  const {fps: f} = useVideoConfig();
  const p = springIn(frame, f, 8);
  const zoom = interpolate(frame, [0, frames], [1.9, 2.05], {easing: easeOut});
  return (
    <AbsoluteFill
      style={{
        alignItems: 'center',
        justifyContent: 'center',
        opacity: useSceneFade(frames),
        fontFamily,
      }}
    >
      <div
        style={{
          opacity: p,
          transform: `scale(${zoom})`,
          borderRadius: 14,
          overflow: 'hidden',
          boxShadow: '0 24px 80px rgba(0,0,0,0.6), 0 0 0 1px rgba(255,255,255,0.08)',
        }}
      >
        <Img src={asset('menubar-limits.png')} style={{width: 530, display: 'block'}} />
      </div>
      <Caption text="Session and weekly limits, one glance away." delay={14} />
    </AbsoluteFill>
  );
};

const TrustScene: React.FC<{frames: number}> = ({frames}) => {
  const frame = useCurrentFrame();
  const {fps: f} = useVideoConfig();
  const lines = ['Local first.', 'No accounts.', 'No subscriptions.'];
  return (
    <AbsoluteFill
      style={{
        alignItems: 'center',
        justifyContent: 'center',
        fontFamily,
        opacity: useSceneFade(frames),
      }}
    >
      <div style={{display: 'flex', flexDirection: 'column', gap: 26, textAlign: 'center'}}>
        {lines.map((line, i) => {
          const p = springIn(frame, f, 14 + i * 26);
          return (
            <div
              key={line}
              style={{
                fontSize: 58,
                fontWeight: 650,
                letterSpacing: -0.8,
                color: i === 0 ? colors.accent : colors.text,
                opacity: p,
                transform: `translateY(${interpolate(p, [0, 1], [22, 0])}px)`,
              }}
            >
              {line}
            </div>
          );
        })}
      </div>
      <Caption text="Your data never leaves your Mac." delay={90} />
    </AbsoluteFill>
  );
};

const Outro: React.FC<{frames: number}> = ({frames}) => {
  const frame = useCurrentFrame();
  const {fps: f} = useVideoConfig();
  const icon = springIn(frame, f, 6);
  const name = springIn(frame, f, 20);
  const tag = springIn(frame, f, 38);
  const url = springIn(frame, f, 58);
  return (
    <AbsoluteFill
      style={{
        alignItems: 'center',
        justifyContent: 'center',
        fontFamily,
        opacity: useSceneFade(frames),
      }}
    >
      <Img
        src={staticFile('logo.png')}
        style={{width: 128, height: 128, opacity: icon}}
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
        One app instead of five subscriptions.
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
    </AbsoluteFill>
  );
};

const SimpleShot: React.FC<{
  frames: number;
  src: string;
  caption: string;
  originY?: string;
  panY?: [number, number];
}> = ({frames, src, caption, originY, panY}) => (
  <AbsoluteFill style={{opacity: useSceneFade(frames), fontFamily}}>
    <WindowShot src={src} frames={frames} originY={originY} panY={panY} />
    <Caption text={caption} />
  </AbsoluteFill>
);

export const Announcement: React.FC = () => {
  return (
    <AbsoluteFill style={{background: colors.bg}}>
      <Backdrop />
      <Audio src={asset('music-bed.m4a')} volume={0.5} />
      {SCENES.map((s) => (
        <Sequence key={s.id} from={sceneStart(s.id)} durationInFrames={s.frames}>
          <Audio src={asset(`vo/${s.vo}`)} volume={1} />
          {s.id === 'cold' && <ColdOpen frames={s.frames} />}
          {s.id === 'notchIntro' && <NotchIntro frames={s.frames} />}
          {s.id === 'shelfTabs' && <ShelfTabs frames={s.frames} />}
          {s.id === 'alert' && <AlertScene frames={s.frames} />}
          {s.id === 'home' && (
            <SimpleShot
              frames={s.frames}
              src="home.jpg"
              caption="One window brings it together."
            />
          )}
          {s.id === 'dashboard' && <DashboardScene frames={s.frames} />}
          {s.id === 'menubar' && <MenubarScene frames={s.frames} />}
          {s.id === 'music' && (
            <SimpleShot
              frames={s.frames}
              src="music.jpg"
              caption="Your local music, played beautifully."
              originY="70%"
            />
          )}
          {s.id === 'system' && (
            <SimpleShot
              frames={s.frames}
              src="system.jpg"
              caption="Runaway apps. Junk. Sleep. Handled."
            />
          )}
          {s.id === 'extensions' && (
            <SimpleShot
              frames={s.frames}
              src="extensions.jpg"
              caption="Twelve extensions. Every one optional."
              panY={[6, -12]}
            />
          )}
          {s.id === 'trust' && <TrustScene frames={s.frames} />}
          {s.id === 'outro' && <Outro frames={s.frames} />}
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};
