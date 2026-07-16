import React from 'react';
import {useCurrentFrame, useVideoConfig, interpolate} from 'remotion';
import {Background} from '../components/Background';
import {AppFrame, SectionLabel} from '../components/AppFrame';
import {Ring} from '../components/Ring';
import {LimitsChart} from '../components/LimitsChart';
import {Caption} from '../components/Caption';
import {springIn} from '../animation';
import {colors, fontFamily} from '../tokens';

const SWITCH_AT = 118;

export const AgentUsageRings: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const sessionP = springIn(frame, fps, 10);
  const weekP = springIn(frame, fps, 20);
  const chartP = interpolate(frame, [55, 125], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const onCodex = frame >= SWITCH_AT;
  const swapPop = onCodex ? springIn(frame, fps, SWITCH_AT) : 1;
  const session = onCodex ? 9 : 14;
  const week = onCodex ? 22 : 35;

  return (
    <Background>
      <AppFrame activeIndex={0}>
        <SectionLabel>LIMITS</SectionLabel>
        <div
          style={{
            display: 'flex',
            gap: 10,
            justifyContent: 'center',
            marginBottom: 24,
            fontFamily,
          }}
        >
          {['Claude', 'Codex'].map((p) => {
            const active = (p === 'Codex') === onCodex;
            return (
              <div
                key={p}
                style={{
                  padding: '7px 22px',
                  borderRadius: 999,
                  fontSize: 17,
                  fontWeight: 600,
                  border: `1px solid ${active ? colors.accent : colors.border}`,
                  color: active ? colors.accent : colors.textDim,
                  background: active ? colors.accentSoft : 'transparent',
                }}
              >
                {p}
              </div>
            );
          })}
        </div>
        <div
          style={{
            display: 'flex',
            gap: 56,
            justifyContent: 'center',
            marginBottom: 28,
            opacity: interpolate(swapPop, [0, 1], [0.4, 1]),
            transform: `scale(${interpolate(swapPop, [0, 1], [0.97, 1])})`,
          }}
        >
          <Ring
            percent={session}
            progress={interpolate(sessionP, [0, 1], [0, 1])}
            label="SESSION"
            startSeconds={3 * 3600 + 33 * 60 + 43}
          />
          <Ring
            percent={week}
            progress={interpolate(weekP, [0, 1], [0, 1])}
            label="WEEK"
            startSeconds={4 * 86400 + 13 * 3600 + 43 * 60 + 43}
          />
        </div>
        <LimitsChart progress={chartP} />
      </AppFrame>
      <Caption delay={65}>Claude and Codex, live limits</Caption>
    </Background>
  );
};
