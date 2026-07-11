import React from 'react';
import {interpolate, useCurrentFrame, useVideoConfig} from 'remotion';
import {Background} from '../components/Background';
import {colors, fontFamily} from '../tokens';
import {springIn} from '../animation';

export const pileupItems = [
  {feature: 'Clipboard history', app: 'a paste manager', price: 6},
  {feature: 'Focus dimming', app: 'a screen dimmer', price: 5},
  {feature: 'Local music', app: 'a music player', price: 5},
  {feature: 'Color picker', app: 'a menu-bar utility', price: 5},
  {feature: 'Per-app volume', app: 'a volume mixer', price: 5},
  {feature: 'AI rate limits', app: 'a usage tracker', price: 8},
  {feature: 'Menu-bar stats', app: 'a readout app', price: 5},
  {feature: 'Usage alerts', app: 'an alerts service', price: 6},
  {feature: 'Usage analytics', app: 'a dashboard', price: 12},
  {feature: 'Spend heatmap', app: 'a calendar tool', price: 4},
  {feature: 'Mic mute', app: 'a hotkey utility', price: 4},
  {feature: 'Disk junk', app: 'a cleaner', price: 5},
];

export const pileupTotal = pileupItems.reduce((a, b) => a + b.price, 0);

export const ProblemHook: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const line = springIn(frame, fps, 8);
  const sub = springIn(frame, fps, 30);
  return (
    <Background>
      <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', fontFamily}}>
        <div
          style={{
            fontSize: 58,
            fontWeight: 800,
            letterSpacing: -1,
            color: colors.text,
            maxWidth: 1100,
            textAlign: 'center',
            lineHeight: 1.15,
            opacity: line,
            transform: `translateY(${interpolate(line, [0, 1], [18, 0])}px)`,
          }}
        >
          What does it cost to make a Mac feel complete?
        </div>
        <div
          style={{
            marginTop: 22,
            fontSize: 27,
            color: colors.textDim,
            opacity: sub,
            transform: `translateY(${interpolate(sub, [0, 1], [14, 0])}px)`,
          }}
        >
          Let&apos;s do the math.
        </div>
      </div>
    </Background>
  );
};

export const PileupStage: React.FC<{
  revealFrom: number;
  revealTo: number;
  showTotal?: boolean;
  collapse?: boolean;
}> = ({revealFrom, revealTo, showTotal = false, collapse = false}) => {
  const frame = useCurrentFrame();
  const {fps, durationInFrames} = useVideoConfig();

  const landed = (i: number) => i < revealFrom || frame >= 14 + (i - revealFrom) * 8;
  const running = pileupItems
    .slice(0, revealTo)
    .reduce((a, b, i) => (landed(i) ? a + b.price : a), 0);

  const counter = running;

  const out = collapse
    ? interpolate(frame, [durationInFrames - 26, durationInFrames - 6], [1, 0], {
        extrapolateLeft: 'clamp',
        extrapolateRight: 'clamp',
      })
    : 1;

  const totalIn = springIn(frame, fps, showTotal ? 10 : 6);

  return (
    <Background>
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          fontFamily,
          opacity: out,
          transform: `scale(${0.92 + out * 0.08})`,
        }}
      >
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(3, 340px)',
            gap: 16,
          }}
        >
          {pileupItems.map((it, i) => {
            if (i >= revealTo) {
              return <div key={it.feature} style={{height: 78}} />;
            }
            const revealed = i < revealFrom;
            const p = revealed ? 1 : springIn(frame, fps, 10 + (i - revealFrom) * 8, true);
            return (
              <div
                key={it.feature}
                style={{
                  borderRadius: 16,
                  background: colors.panel,
                  border: `1px solid ${colors.border}`,
                  padding: '15px 20px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  opacity: interpolate(p, [0, 1], [0, 1]),
                  transform: `translateY(${interpolate(p, [0, 1], [26, 0])}px) rotate(${interpolate(p, [0, 1], [-3, 0])}deg)`,
                }}
              >
                <div>
                  <div style={{color: colors.text, fontSize: 20, fontWeight: 700}}>
                    {it.feature}
                  </div>
                  <div style={{color: colors.label, fontSize: 14, marginTop: 3}}>{it.app}</div>
                </div>
                <div
                  style={{
                    color: colors.textDim,
                    fontSize: 19,
                    fontWeight: 700,
                    whiteSpace: 'nowrap',
                  }}
                >
                  ${it.price}
                  <span style={{color: colors.label, fontSize: 12, fontWeight: 600}}>/mo</span>
                </div>
              </div>
            );
          })}
        </div>

        <div
          style={{
            marginTop: 40,
            display: 'flex',
            alignItems: 'baseline',
            gap: 14,
            fontSize: 24,
            color: colors.textDim,
            opacity: revealTo > 2 ? totalIn : 0,
          }}
        >
          {showTotal ? (
            <>
              <span style={{fontSize: 26}}>Twelve subscriptions.</span>
              <span style={{color: colors.accent, fontSize: 44, fontWeight: 800}}>
                ${counter}/mo
              </span>
              <span
                style={{
                  color: colors.text,
                  fontSize: 26,
                  fontWeight: 700,
                  opacity: springIn(frame, fps, 62),
                }}
              >
                Forever.
              </span>
            </>
          ) : (
            <>
              <span>Running total</span>
              <span style={{color: colors.accent, fontSize: 34, fontWeight: 800}}>
                ${counter}/mo
              </span>
            </>
          )}
        </div>
      </div>
    </Background>
  );
};
