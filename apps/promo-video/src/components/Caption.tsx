import React from 'react';
import {useCurrentFrame, useVideoConfig} from 'remotion';
import {colors, fontFamily} from '../tokens';
import {fadeUp} from '../animation';

export const CaptionsEnabled = React.createContext(true);

export const Caption: React.FC<{children: React.ReactNode; delay?: number}> = ({
  children,
  delay = 20,
}) => {
  const enabled = React.useContext(CaptionsEnabled);
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const style = fadeUp(frame, fps, delay);

  if (!enabled) return null;

  return (
    <div
      style={{
        position: 'absolute',
        bottom: 90,
        left: 0,
        right: 0,
        display: 'flex',
        justifyContent: 'center',
        fontFamily,
        color: colors.textDim,
        fontSize: 20,
        letterSpacing: 2,
        ...style,
      }}
    >
      {children}
    </div>
  );
};
