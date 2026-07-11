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
      </div>
    </Background>
  );
};

const SCENES: Array<{
  id: string;
  frames: number;
  vo?: string;
  node: React.ReactNode;
}> = [
  {id: 'cold', frames: 150, vo: 'L01.mp3', node: <ColdOpen />},
  {id: 'notchHero', frames: 240, vo: 'L02.mp3', node: <NotchHeroScene />},
  {id: 'notchTabs', frames: 195, vo: 'L03.mp3', node: <NotchTabsScene />},
  {id: 'alert', frames: 105, vo: 'L04.mp3', node: <NotchAlertScene />},
  {id: 'home', frames: 110, vo: 'L05.mp3', node: <HomeDashboardScene />},
  {id: 'rings', frames: 150, vo: 'L06.mp3', node: <AgentUsageRings />},
  {id: 'stats', frames: 95, vo: 'L06b.mp3', node: <UsageStats />},
  {id: 'heatmap', frames: 95, vo: 'L06c.mp3', node: <ActivityHeatmap />},
  {id: 'menubar', frames: 130, vo: 'L07.mp3', node: <MenuBarBadgeScene />},
  {id: 'music', frames: 110, vo: 'L08.mp3', node: <MusicScene />},
  {id: 'system', frames: 150, vo: 'L09.mp3', node: <SystemScene />},
  {id: 'settings', frames: 125, vo: 'L10.mp3', node: <SettingsMontage />},
  {id: 'trust', frames: 170, vo: 'L11.mp3', node: <TrustScene />},
  {id: 'outro', frames: 190, vo: 'L12.mp3', node: <AnnouncementOutro />},
];

export const announcementDuration = SCENES.reduce((a, s) => a + s.frames, 0);

export const Announcement: React.FC = () => {
  let at = 0;
  return (
    <AbsoluteFill style={{background: colors.bg}}>
      <Audio src={asset('music-bed.m4a')} volume={0.9} />
      {SCENES.map((s) => {
        const from = at;
        at += s.frames;
        return (
          <Sequence key={s.id} from={from} durationInFrames={s.frames}>
            {s.vo ? <Audio src={asset(`vo/${s.vo}`)} /> : null}
            <SceneFade frames={s.frames}>{s.node}</SceneFade>
          </Sequence>
        );
      })}
    </AbsoluteFill>
  );
};
