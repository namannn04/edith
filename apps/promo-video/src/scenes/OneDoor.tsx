import React from 'react';
import {useCurrentFrame, useVideoConfig, Img, staticFile, interpolate} from 'remotion';
import {Background} from '../components/Background';
import {colors, fontFamily} from '../tokens';
import {springIn} from '../animation';

export const OneDoor: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const mark = springIn(frame, fps, 0, true);
  const line = springIn(frame, fps, 14);
  const sub = springIn(frame, fps, 24);

  return (
    <Background>
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          fontFamily,
        }}
      >
        <Img
          src={staticFile('logo.png')}
          style={{
            width: 104,
            height: 104,
            borderRadius: 26,
            opacity: interpolate(mark, [0, 1], [0, 1]),
            transform: `scale(${interpolate(mark, [0, 1], [0.4, 1])})`,
            boxShadow: '0 0 80px rgba(245,166,35,0.28)',
          }}
        />
        <div
          style={{
            marginTop: 34,
            color: colors.text,
            fontSize: 46,
            fontWeight: 800,
            letterSpacing: 0.5,
            opacity: interpolate(line, [0, 1], [0, 1]),
            transform: `translateY(${interpolate(line, [0, 1], [16, 0])}px)`,
          }}
        >
          One app. Every tool.
        </div>
        <div
          style={{
            marginTop: 14,
            color: colors.accent,
            fontSize: 24,
            fontWeight: 700,
            letterSpacing: 2,
            opacity: interpolate(sub, [0, 1], [0, 1]),
            transform: `translateY(${interpolate(sub, [0, 1], [12, 0])}px)`,
          }}
        >
          Zero subscriptions. Works out of the box.
        </div>
      </div>
    </Background>
  );
};
