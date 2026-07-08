import React from 'react';
import {useCurrentFrame, useVideoConfig, interpolate} from 'remotion';
import {Background} from '../components/Background';
import {colors, fontFamily} from '../tokens';
import {springIn} from '../animation';

const items = [
  {feature: 'Clipboard history', app: 'a paste manager', price: 3},
  {feature: 'Screen dimming', app: 'a focus dimmer', price: 5},
  {feature: 'Command launcher', app: 'a hotkey app', price: 8},
  {feature: 'Clocks + agenda', app: 'a menu-bar clock', price: 6},
  {feature: 'File shelf', app: 'a drop shelf', price: 5},
  {feature: 'Usage & cost', app: 'a tracker', price: 12},
];

const total = items.reduce((a, b) => a + b.price, 0);

export const SubscriptionPileup: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps, durationInFrames} = useVideoConfig();

  const heading = springIn(frame, fps, 0);
  const counter = Math.round(
    interpolate(frame, [46, 96], [0, total], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    }),
  );

  const collapse = interpolate(
    frame,
    [durationInFrames - 26, durationInFrames - 4],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );

  return (
    <Background>
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          fontFamily,
          opacity: collapse,
          transform: `scale(${0.9 + collapse * 0.1})`,
        }}
      >
        <div
          style={{
            color: colors.textDim,
            fontSize: 26,
            letterSpacing: 1,
            fontWeight: 600,
            opacity: interpolate(heading, [0, 1], [0, 1]),
            transform: `translateY(${interpolate(heading, [0, 1], [14, 0])}px)`,
          }}
        >
          Everyone else sells it one app at a time.
        </div>

        <div
          style={{
            marginTop: 44,
            display: 'grid',
            gridTemplateColumns: 'repeat(3, 300px)',
            gap: 20,
          }}
        >
          {items.map((it, i) => {
            const p = springIn(frame, fps, 16 + i * 7, true);
            return (
              <div
                key={it.feature}
                style={{
                  borderRadius: 18,
                  background: colors.panel,
                  border: `1px solid ${colors.border}`,
                  padding: '20px 22px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  opacity: interpolate(p, [0, 1], [0, 1]),
                  transform: `translateY(${interpolate(p, [0, 1], [26, 0])}px) rotate(${interpolate(p, [0, 1], [-3, 0])}deg)`,
                }}
              >
                <div>
                  <div style={{color: colors.text, fontSize: 19, fontWeight: 700}}>
                    {it.feature}
                  </div>
                  <div style={{color: colors.label, fontSize: 14, marginTop: 4}}>
                    {it.app}
                  </div>
                </div>
                <div
                  style={{
                    color: colors.textDim,
                    fontSize: 18,
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
            marginTop: 42,
            display: 'flex',
            alignItems: 'baseline',
            gap: 14,
            color: colors.textDim,
            fontSize: 22,
          }}
        >
          <span>Six logins, six updates,</span>
          <span style={{color: colors.accent, fontSize: 34, fontWeight: 800}}>
            ${counter}/mo
          </span>
        </div>
      </div>
    </Background>
  );
};
