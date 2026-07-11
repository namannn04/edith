import React from 'react';
import {interpolate, useCurrentFrame, useVideoConfig} from 'remotion';
import {Background} from '../components/Background';
import {colors, fontFamily} from '../tokens';
import {springIn} from '../animation';

const Stat: React.FC<{value: string; label: string; delay: number}> = ({value, label, delay}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const p = springIn(frame, fps, delay, true);
  return (
    <div
      style={{
        opacity: interpolate(p, [0, 1], [0, 1]),
        transform: `translateY(${interpolate(p, [0, 1], [22, 0])}px)`,
        textAlign: 'center',
      }}
    >
      <div style={{color: colors.accent, fontSize: 84, fontWeight: 800, lineHeight: 1}}>
        {value}
      </div>
      <div style={{color: colors.label, fontSize: 16, letterSpacing: 2, marginTop: 12}}>
        {label}
      </div>
    </div>
  );
};

const SWAP = 118;

export const NativeScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const q = springIn(frame, fps, 8);
  const qOut = interpolate(frame, [SWAP - 12, SWAP], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const punch = springIn(frame, fps, SWAP + 4);
  return (
    <Background>
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          fontFamily,
          textAlign: 'center',
        }}
      >
        {frame < SWAP ? (
          <div
            style={{
              fontSize: 54,
              fontWeight: 800,
              letterSpacing: -1,
              color: colors.text,
              maxWidth: 1100,
              lineHeight: 1.2,
              opacity: q * qOut,
              transform: `translateY(${interpolate(q, [0, 1], [18, 0])}px)`,
            }}
          >
            All of this must be heavy&hellip; right?
          </div>
        ) : (
          <>
            <div
              style={{
                fontSize: 54,
                fontWeight: 800,
                letterSpacing: -1,
                color: colors.text,
                opacity: punch,
                transform: `translateY(${interpolate(punch, [0, 1], [18, 0])}px)`,
              }}
            >
              Nope. One <span style={{color: colors.accent}}>native Swift</span> app.
            </div>
            <div style={{display: 'flex', gap: 120, marginTop: 70}}>
              <Stat value="~0%" label="CPU, PANEL CLOSED" delay={SWAP + 66} />
              <Stat value="22 MB" label="MEMORY" delay={SWAP + 112} />
            </div>
          </>
        )}
      </div>
    </Background>
  );
};
