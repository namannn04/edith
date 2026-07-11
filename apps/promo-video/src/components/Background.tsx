import React from 'react';
import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {colors} from '../tokens';

export const Background: React.FC<{children: React.ReactNode}> = ({
  children,
}) => {
  const frame = useCurrentFrame();
  const t = frame / 30;
  const x1 = 32 + Math.sin(t * 0.11) * 14;
  const y1 = -8 + Math.cos(t * 0.09) * 8;
  const x2 = 74 + Math.cos(t * 0.07) * 12;
  const y2 = 92 + Math.sin(t * 0.08) * 8;
  return (
    <AbsoluteFill
      style={{
        background: colors.bgVignette,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <AbsoluteFill
        style={{
          background: `radial-gradient(46% 38% at ${x1}% ${y1}%, rgba(245,166,35,0.075) 0%, transparent 70%),
            radial-gradient(40% 34% at ${x2}% ${y2}%, rgba(120,150,245,0.05) 0%, transparent 70%)`,
        }}
      />
      <AbsoluteFill
        style={{
          background:
            'radial-gradient(120% 90% at 50% 50%, transparent 55%, rgba(0,0,0,0.35) 100%)',
        }}
      />
      {children}
    </AbsoluteFill>
  );
};
