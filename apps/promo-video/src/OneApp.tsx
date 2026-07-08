import React from 'react';
import {TransitionSeries, linearTiming} from '@remotion/transitions';
import {fade} from '@remotion/transitions/fade';
import {transitionFrames} from './tokens';
import {SubscriptionPileup} from './scenes/SubscriptionPileup';
import {OneDoor} from './scenes/OneDoor';
import {ClipboardScene} from './scenes/ClipboardScene';
import {FocusDimScene} from './scenes/FocusDimScene';
import {NotchShelfScene} from './scenes/NotchShelfScene';
import {HomeDashboardScene} from './scenes/HomeDashboardScene';
import {HotkeysScene} from './scenes/HotkeysScene';
import {AgentUsageRings} from './scenes/AgentUsageRings';
import {CalendarScene} from './scenes/CalendarScene';
import {MusicScene} from './scenes/MusicScene';
import {LeastResourcesScene} from './scenes/LeastResourcesScene';
import {Outro} from './scenes/Outro';

export const oneAppDurations = {
  pileup: 165,
  oneDoor: 80,
  clipboard: 115,
  focusDim: 115,
  notchShelf: 115,
  homeDashboard: 140,
  hotkeys: 105,
  rings: 145,
  calendar: 135,
  music: 140,
  leastResources: 130,
  outro: 90,
};

const sceneCount = Object.keys(oneAppDurations).length;
export const oneAppTotalDuration =
  Object.values(oneAppDurations).reduce((a, b) => a + b, 0) -
  (sceneCount - 1) * transitionFrames;

const T = () => (
  <TransitionSeries.Transition
    presentation={fade()}
    timing={linearTiming({durationInFrames: transitionFrames})}
  />
);

const scenes: [keyof typeof oneAppDurations, React.FC][] = [
  ['pileup', SubscriptionPileup],
  ['oneDoor', OneDoor],
  ['clipboard', ClipboardScene],
  ['focusDim', FocusDimScene],
  ['notchShelf', NotchShelfScene],
  ['homeDashboard', HomeDashboardScene],
  ['hotkeys', HotkeysScene],
  ['rings', AgentUsageRings],
  ['calendar', CalendarScene],
  ['music', MusicScene],
  ['leastResources', LeastResourcesScene],
  ['outro', Outro],
];

export const OneApp: React.FC = () => {
  return (
    <TransitionSeries>
      {scenes.map(([key, Scene], i) => (
        <React.Fragment key={key}>
          {i > 0 && T()}
          <TransitionSeries.Sequence durationInFrames={oneAppDurations[key]}>
            <Scene />
          </TransitionSeries.Sequence>
        </React.Fragment>
      ))}
    </TransitionSeries>
  );
};
