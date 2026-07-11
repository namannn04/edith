import React from 'react';
import {interpolate, useCurrentFrame, useVideoConfig} from 'remotion';
import {Background} from '../components/Background';
import {Caption} from '../components/Caption';
import {colors, fontFamily} from '../tokens';
import {easeOut, springIn} from '../animation';
import {
  AppleIcon,
  BatteryIcon,
  BoltIcon,
  CameraIcon,
  ChipIcon,
  ClipboardIcon,
  EyedropperIcon,
  FolderIcon,
  GearIcon,
  HouseIcon,
  KeyboardIcon,
  MicIcon,
  MoonIcon,
  NextIcon,
  PauseIcon,
  PinIcon,
  PresenterIcon,
  PrevIcon,
  TrashIcon,
} from './icons';

const mono =
  '"SF Mono", ui-monospace, Menlo, monospace';

const SCREEN_W = 1500;
const SCREEN_H = 930;
const NOTCH_COLLAPSED_W = 320;
const NOTCH_COLLAPSED_H = 34;
const SHELF_W = 620;
const SHELF_H = 252;

const EqBars: React.FC<{playing: boolean}> = ({playing}) => {
  const frame = useCurrentFrame();
  return (
    <div style={{display: 'flex', gap: 2.5, alignItems: 'flex-end', height: 13}}>
      {[0, 1, 2, 3].map((i) => {
        const h = playing
          ? 4 + Math.abs(Math.sin(frame * 0.31 + i * 1.7)) * 9
          : 4;
        return (
          <div
            key={i}
            style={{width: 2.5, height: h, borderRadius: 2, background: '#fff'}}
          />
        );
      })}
    </div>
  );
};

const CoverThumb: React.FC<{size: number; radius?: number}> = ({size, radius = 8}) => (
  <div
    style={{
      width: size,
      height: size,
      borderRadius: radius,
      background:
        'radial-gradient(120% 120% at 30% 25%, #3a3070 0%, #241c4e 40%, #b35a2c 100%)',
      position: 'relative',
      overflow: 'hidden',
      flexShrink: 0,
    }}
  >
    {[0.3, 0.5, 0.7].map((r) => (
      <div
        key={r}
        style={{
          position: 'absolute',
          left: '50%',
          top: '50%',
          width: size * r,
          height: size * r,
          borderRadius: '50%',
          border: '1px solid rgba(255,255,255,0.18)',
          transform: 'translate(-50%, -50%)',
        }}
      />
    ))}
  </div>
);

const MiniRing: React.FC<{
  percent: number;
  progress: number;
  topLabel: string;
  bottomLabel: string;
}> = ({percent, progress, topLabel, bottomLabel}) => {
  const size = 74;
  const stroke = 5;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const shown = percent * progress;
  return (
    <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3}}>
      <div style={{position: 'relative', width: size, height: size}}>
        <svg width={size} height={size} style={{transform: 'rotate(-90deg)'}}>
          <circle cx={size / 2} cy={size / 2} r={r} stroke="#2c2c2e" strokeWidth={stroke} fill="none" />
          <circle
            cx={size / 2}
            cy={size / 2}
            r={r}
            stroke="#4cd964"
            strokeWidth={stroke}
            fill="none"
            strokeLinecap="round"
            strokeDasharray={c}
            strokeDashoffset={c * (1 - shown / 100)}
          />
        </svg>
        <div
          style={{
            position: 'absolute',
            inset: 0,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#fff',
            fontSize: 17,
            fontWeight: 700,
          }}
        >
          {Math.round(shown)}%
        </div>
      </div>
      <div style={{color: '#fff', fontSize: 11, fontWeight: 600}}>{topLabel}</div>
      <div style={{color: 'rgba(255,255,255,0.45)', fontSize: 10, fontFamily: mono}}>
        {bottomLabel}
      </div>
    </div>
  );
};

const QuickAction: React.FC<{icon: React.ReactNode; label: string; active?: boolean}> = ({
  icon,
  label,
  active,
}) => (
  <div
    style={{
      flex: 1,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 7,
      padding: '10px 0',
      borderRadius: 12,
      background: active ? '#d99a55' : 'rgba(255,255,255,0.07)',
      color: active ? '#1d1206' : '#fff',
      fontSize: 12.5,
      fontWeight: 600,
      whiteSpace: 'nowrap',
    }}
  >
    {icon}
    {label}
  </div>
);

const TabPills: React.FC<{active: 'home' | 'files' | 'clipboard'}> = ({active}) => {
  const pill = (id: string, icon: React.ReactNode, label?: string) => {
    const isActive = id === active;
    return (
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 6,
          padding: label && isActive ? '6px 13px' : '6px 10px',
          borderRadius: 999,
          background: isActive ? '#f2f2f2' : 'rgba(255,255,255,0.09)',
          color: isActive ? '#111' : 'rgba(255,255,255,0.85)',
          fontSize: 12.5,
          fontWeight: 700,
        }}
      >
        {icon}
        {isActive ? label ?? null : null}
      </div>
    );
  };
  return (
    <div style={{display: 'flex', alignItems: 'center', gap: 7}}>
      {pill('home', <HouseIcon size={13} />, 'Home')}
      {pill('files', <FolderIcon size={13} />, 'Files')}
      {pill('clipboard', <ClipboardIcon size={13} />, 'Clipboard')}
      {pill('camera', <CameraIcon size={13} />)}
      <div style={{flex: 1}} />
      <span style={{color: 'rgba(255,255,255,0.5)'}}>
        <GearIcon size={14} />
      </span>
    </div>
  );
};

const HomeTab: React.FC<{contentP: number; startFrame: number}> = ({
  contentP,
  startFrame,
}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const local = Math.max(0, frame - startFrame);
  const ringP = interpolate(local, [8, 45], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: easeOut,
  });
  const progress = Math.min(0.92, 0.06 + local / fps / 60);
  return (
    <div style={{opacity: contentP, display: 'flex', flexDirection: 'column', gap: 10, flex: 1}}>
      <div style={{display: 'flex', gap: 10, flex: 1}}>
        <div
          style={{
            flex: 1.7,
            borderRadius: 14,
            background: 'rgba(255,255,255,0.05)',
            padding: '12px 14px',
            display: 'flex',
            alignItems: 'center',
            gap: 12,
          }}
        >
          <CoverThumb size={52} />
          <div style={{flex: 1, minWidth: 0}}>
            <div style={{color: '#fff', fontSize: 14.5, fontWeight: 700}}>Slow Orbit</div>
            <div style={{color: 'rgba(255,255,255,0.45)', fontSize: 11.5, marginTop: 1}}>
              Music
            </div>
            <div
              style={{
                marginTop: 8,
                height: 3,
                borderRadius: 2,
                background: 'rgba(255,255,255,0.16)',
                overflow: 'hidden',
              }}
            >
              <div
                style={{
                  width: `${progress * 100}%`,
                  height: '100%',
                  background: '#fff',
                  borderRadius: 2,
                }}
              />
            </div>
          </div>
          <div style={{display: 'flex', gap: 13, color: '#fff', alignItems: 'center'}}>
            <PrevIcon size={15} />
            <PauseIcon size={16} />
            <NextIcon size={15} />
          </div>
        </div>
        <div
          style={{
            flex: 1,
            borderRadius: 14,
            background: 'rgba(255,255,255,0.05)',
            padding: '8px 10px',
            display: 'flex',
            gap: 12,
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <MiniRing percent={14} progress={ringP} topLabel="5h" bottomLabel="3:26:18" />
          <MiniRing percent={35} progress={ringP} topLabel="7d" bottomLabel="5d 5:08" />
        </div>
      </div>
      <div style={{display: 'flex', gap: 8}}>
        {[
          {icon: <KeyboardIcon size={13} />, label: 'Clean keys'},
          {icon: <MoonIcon size={13} />, label: 'Keep awake', active: true},
          {icon: <PresenterIcon size={13} />, label: 'Presenter'},
          {icon: <EyedropperIcon size={13} />, label: 'Pick color'},
        ].map((a, i) => {
          const p = springIn(frame, fps, startFrame + 10 + i * 4);
          return (
            <div key={a.label} style={{flex: 1, opacity: p, transform: `translateY(${(1 - p) * 10}px)`, display: 'flex'}}>
              <QuickAction icon={a.icon} label={a.label} active={a.active} />
            </div>
          );
        })}
      </div>
    </div>
  );
};

const FilesTab: React.FC<{startFrame: number}> = ({startFrame}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const files = [
    {name: 'launch-mock.png', kind: 'image'},
    {name: 'launch-notes.txt', kind: 'text'},
    {name: 'release-notes.txt', kind: 'text'},
  ];
  return (
    <div style={{display: 'flex', gap: 22, padding: '10px 6px'}}>
      {files.map((f, i) => {
        const p = springIn(frame, fps, startFrame + 6 + i * 7, true);
        return (
          <div
            key={f.name}
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: 8,
              opacity: interpolate(p, [0, 1], [0, 1]),
              transform: `translateY(${interpolate(p, [0, 1], [46, 0])}px)`,
            }}
          >
            {f.kind === 'image' ? (
              <div
                style={{
                  width: 62,
                  height: 44,
                  borderRadius: 7,
                  border: '1px solid rgba(245,166,35,0.55)',
                  background: 'linear-gradient(160deg, #241f1a 0%, #0d0c0a 100%)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: '#f5a623',
                  fontSize: 8,
                }}
              >
                Edith 2.0
              </div>
            ) : (
              <div
                style={{
                  width: 46,
                  height: 56,
                  borderRadius: 6,
                  background: '#f4f2ee',
                  padding: '7px 6px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 3,
                }}
              >
                {[0.9, 0.75, 0.85, 0.6, 0.8].map((w, j) => (
                  <div
                    key={j}
                    style={{
                      width: `${w * 100}%`,
                      height: 2.5,
                      borderRadius: 2,
                      background: 'rgba(0,0,0,0.35)',
                    }}
                  />
                ))}
              </div>
            )}
            <span style={{color: '#fff', fontSize: 11.5, fontWeight: 600}}>{f.name}</span>
          </div>
        );
      })}
    </div>
  );
};

const ClipboardTab: React.FC<{startFrame: number}> = ({startFrame}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const rows = [
    '#F5A623',
    'git rebase -i origin/main',
    'https://edith.app/download',
    'Ship the announcement video Friday',
  ];
  return (
    <div style={{display: 'flex', flexDirection: 'column', gap: 7, flex: 1}}>
      {rows.map((r, i) => {
        const p = springIn(frame, fps, startFrame + 4 + i * 5);
        return (
          <div
            key={r}
            style={{
              display: 'flex',
              alignItems: 'center',
              padding: '9px 13px',
              borderRadius: 11,
              background: 'rgba(255,255,255,0.06)',
              opacity: p,
              transform: `translateX(${(1 - p) * 18}px)`,
            }}
          >
            <span
              style={{
                color: '#fff',
                fontSize: 12.5,
                fontFamily: i < 3 ? mono : fontFamily,
                flex: 1,
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
              }}
            >
              {r}
            </span>
            <span
              style={{
                color: 'rgba(255,255,255,0.35)',
                marginLeft: 12,
                display: 'flex',
                gap: 9,
                alignItems: 'center',
              }}
            >
              <PinIcon size={12} />
              <TrashIcon size={12} />
            </span>
          </div>
        );
      })}
    </div>
  );
};

export const Cursor: React.FC<{x: number; y: number; pressed?: boolean}> = ({x, y, pressed}) => (
  <svg
    width={26}
    height={26}
    viewBox="0 0 24 24"
    style={{
      position: 'absolute',
      left: x,
      top: y,
      zIndex: 60,
      transform: pressed ? 'scale(0.88)' : 'scale(1)',
      filter: 'drop-shadow(0 2px 6px rgba(0,0,0,0.6))',
    }}
  >
    <path
      d="M5.5 2.2 L5.5 18.6 L9.6 14.9 L12.2 21 L14.9 19.8 L12.3 13.9 L17.8 13.6 Z"
      fill="#fff"
      stroke="#000"
      strokeWidth="1.1"
    />
  </svg>
);

export const MacScreen: React.FC<{
  children: React.ReactNode;
  scale?: number;
  originY?: string;
}> = ({children, scale = 1, originY = '50%'}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const enter = springIn(frame, fps, 0);
  return (
    <div
      style={{
        position: 'relative',
        width: SCREEN_W,
        height: SCREEN_H,
        borderRadius: 26,
        background: 'linear-gradient(180deg, #16181d 0%, #101216 55%, #0b0d10 100%)',
        border: '2px solid #2a2d33',
        boxShadow:
          '0 60px 140px rgba(0,0,0,0.7), inset 0 0 0 6px #000, inset 0 0 90px rgba(0,0,0,0.5)',
        overflow: 'hidden',
        opacity: enter,
        transform: `scale(${scale * interpolate(enter, [0, 1], [0.97, 1])})`,
        transformOrigin: `50% ${originY}`,
        fontFamily,
      }}
    >
      <div
        style={{
          position: 'absolute',
          inset: 6,
          borderRadius: 20,
          background:
            'radial-gradient(80% 90% at 22% 18%, #4a2f63 0%, transparent 55%), radial-gradient(70% 80% at 82% 30%, #8a4a2c 0%, transparent 55%), radial-gradient(90% 90% at 55% 95%, #1d3a55 0%, transparent 60%), linear-gradient(180deg, #201a2c 0%, #14121c 60%, #0d0c12 100%)',
          overflow: 'hidden',
        }}
      >
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            height: 30,
            background: 'rgba(10,10,12,0.78)',
            backdropFilter: 'blur(10px)',
            display: 'flex',
            alignItems: 'center',
            padding: '0 16px',
            color: 'rgba(255,255,255,0.88)',
            fontSize: 12,
            zIndex: 5,
          }}
        >
          <AppleIcon size={13} />
          <span style={{marginLeft: 16, fontWeight: 700}}>Finder</span>
          <span style={{marginLeft: 16, opacity: 0.65}}>File</span>
          <span style={{marginLeft: 12, opacity: 0.65}}>Edit</span>
          <span style={{marginLeft: 12, opacity: 0.65}}>View</span>
          <div style={{flex: 1}} />
          <span style={{fontFamily: mono, fontSize: 11.5}}>
            <b>5h</b> 14% <b>7d</b> 35%
          </span>
          <span
            style={{
              fontFamily: mono,
              fontSize: 11.5,
              marginLeft: 14,
              display: 'flex',
              alignItems: 'center',
              gap: 4,
            }}
          >
            <ChipIcon size={12} /> 12% <BatteryIcon size={14} /> 75%
          </span>
          <span style={{marginLeft: 14, opacity: 0.8, display: 'flex'}}>
            <MicIcon size={12} />
          </span>
          <span style={{marginLeft: 14, fontSize: 11.5}}>Sat Jul 11 7:35 AM</span>
        </div>
        {children}
      </div>
    </div>
  );
};

export const NotchShelf: React.FC<{
  mode: 'collapsed' | 'hover' | 'open';
  openP: number;
  tab: 'home' | 'files' | 'clipboard';
  tabContentStart: number;
  hoverP?: number;
}> = ({mode, openP, tab, tabContentStart, hoverP = 0}) => {
  const w = interpolate(openP, [0, 1], [NOTCH_COLLAPSED_W, SHELF_W]);
  const h = interpolate(openP, [0, 1], [NOTCH_COLLAPSED_H, SHELF_H]);
  const radius = interpolate(openP, [0, 1], [18, 24]);
  const grow = 1 + hoverP * 0.06;
  const contentP = interpolate(openP, [0.75, 1], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const collapsedP = interpolate(openP, [0, 0.25], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <div
      style={{
        position: 'absolute',
        top: 0,
        left: '50%',
        transform: `translateX(-50%) scale(${grow})`,
        transformOrigin: '50% 0%',
        width: w,
        height: h,
        background: '#000',
        borderBottomLeftRadius: radius,
        borderBottomRightRadius: radius,
        zIndex: 20,
        boxShadow: openP > 0.1 ? '0 30px 70px rgba(0,0,0,0.65)' : 'none',
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          height: NOTCH_COLLAPSED_H,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '0 12px',
          opacity: collapsedP,
        }}
      >
        <CoverThumb size={20} radius={5} />
        <EqBars playing={mode !== 'open'} />
      </div>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          padding: '12px 16px 14px',
          display: 'flex',
          flexDirection: 'column',
          gap: 11,
          opacity: contentP,
        }}
      >
        <TabPills active={tab} />
        {tab === 'home' && <HomeTab contentP={contentP} startFrame={tabContentStart} />}
        {tab === 'files' && <FilesTab startFrame={tabContentStart} />}
        {tab === 'clipboard' && <ClipboardTab startFrame={tabContentStart} />}
      </div>
    </div>
  );
};

export const NotchHeroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const HOVER_AT = 78;
  const OPEN_AT = 100;

  const cursorX = interpolate(frame, [24, HOVER_AT], [1120, 780], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: easeOut,
  });
  const cursorY = interpolate(frame, [24, HOVER_AT], [640, 46], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: easeOut,
  });
  const hoverP = interpolate(frame, [HOVER_AT, HOVER_AT + 10], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const openP = springIn(frame, fps, OPEN_AT, true);
  const pulseP = interpolate(frame, [HOVER_AT, HOVER_AT + 14], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: easeOut,
  });

  return (
    <Background>
      <MacScreen originY="42%">
        {frame >= HOVER_AT && frame < OPEN_AT + 4 ? (
          <div
            style={{
              position: 'absolute',
              top: -26,
              left: '50%',
              transform: `translateX(-50%) scale(${0.9 + pulseP * 0.35})`,
              width: NOTCH_COLLAPSED_W + 60,
              height: 96,
              borderRadius: 40,
              border: '2px solid rgba(245,166,35,0.55)',
              opacity: (1 - pulseP) * 0.9,
              zIndex: 15,
              pointerEvents: 'none',
            }}
          />
        ) : null}
        <NotchShelf
          mode={frame < HOVER_AT ? 'collapsed' : frame < OPEN_AT ? 'hover' : 'open'}
          openP={openP}
          hoverP={hoverP * (1 - Math.min(1, openP * 2))}
          tab="home"
          tabContentStart={OPEN_AT + 14}
        />
        <Cursor
          x={cursorX}
          y={cursorY}
          pressed={frame >= OPEN_AT - 3 && frame <= OPEN_AT + 4}
        />
      </MacScreen>
      <Caption delay={30}>Hover the notch - your shelf springs open</Caption>
    </Background>
  );
};

export const NotchTabsScene: React.FC = () => {
  const frame = useCurrentFrame();
  const SWITCH = 96;
  const tab = frame < SWITCH ? 'files' : 'clipboard';
  return (
    <Background>
      <MacScreen scale={1.32} originY="12%">
        <NotchShelf
          mode="open"
          openP={1}
          tab={tab}
          tabContentStart={tab === 'files' ? 6 : SWITCH + 4}
        />
        <Cursor x={frame < SWITCH ? 736 : 762} y={54} pressed={Math.abs(frame - SWITCH) < 4} />
      </MacScreen>
      <Caption delay={20}>Park files. Reach every copy.</Caption>
    </Background>
  );
};

export const NotchAlertScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const drop = springIn(frame, fps, 10, true);
  const alertW = 380;
  return (
    <Background>
      <MacScreen scale={1.32} originY="12%">
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: '50%',
            transform: 'translateX(-50%)',
            width: interpolate(drop, [0, 1], [NOTCH_COLLAPSED_W, alertW]),
            height: interpolate(drop, [0, 1], [NOTCH_COLLAPSED_H, 84]),
            background: '#000',
            borderBottomLeftRadius: 22,
            borderBottomRightRadius: 22,
            zIndex: 20,
            overflow: 'hidden',
            boxShadow: '0 24px 60px rgba(0,0,0,0.6)',
          }}
        >
          <div
            style={{
              position: 'absolute',
              inset: 0,
              display: 'flex',
              alignItems: 'flex-end',
              padding: '0 20px 15px',
              gap: 13,
              opacity: interpolate(drop, [0.6, 1], [0, 1], {
                extrapolateLeft: 'clamp',
                extrapolateRight: 'clamp',
              }),
            }}
          >
            <div
              style={{
                width: 38,
                height: 38,
                borderRadius: 10,
                background: 'rgba(76,217,100,0.16)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#4cd964',
              }}
            >
              <BoltIcon size={19} />
            </div>
            <div style={{fontFamily}}>
              <div style={{color: '#fff', fontSize: 15, fontWeight: 700}}>Plugged in</div>
              <div style={{color: 'rgba(255,255,255,0.5)', fontSize: 12.5}}>53%</div>
            </div>
          </div>
        </div>
      </MacScreen>
      <Caption delay={20}>Alerts, where your eyes already are</Caption>
    </Background>
  );
};
