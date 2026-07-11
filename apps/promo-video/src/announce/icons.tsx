import React from 'react';

type IconProps = {size?: number; color?: string; strokeWidth?: number};

const base = (
  size: number,
  children: React.ReactNode,
  props: {color: string; strokeWidth: number; filled?: boolean},
) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill={props.filled ? props.color : 'none'}
    stroke={props.filled ? 'none' : props.color}
    strokeWidth={props.strokeWidth}
    strokeLinecap="round"
    strokeLinejoin="round"
    style={{display: 'block', flexShrink: 0}}
  >
    {children}
  </svg>
);

export const HouseIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor', strokeWidth = 2}) =>
  base(size, <><path d="M3 10.5 12 3l9 7.5" /><path d="M5.5 9.5V20h13V9.5" /></>, {color, strokeWidth});

export const FolderIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor', strokeWidth = 2}) =>
  base(size, <path d="M3 6.5A1.5 1.5 0 0 1 4.5 5h4l2 2.5h9A1.5 1.5 0 0 1 21 9v9a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 18Z" />, {color, strokeWidth});

export const ClipboardIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor', strokeWidth = 2}) =>
  base(size, <><rect x="6" y="5" width="12" height="16" rx="2" /><path d="M9 5a3 3 0 0 1 6 0" /><path d="M9.5 11h5M9.5 15h5" /></>, {color, strokeWidth});

export const CameraIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor', strokeWidth = 2}) =>
  base(size, <><path d="M3 8.5A1.5 1.5 0 0 1 4.5 7h3l1.5-2h6L16.5 7h3A1.5 1.5 0 0 1 21 8.5v9a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 17.5Z" /><circle cx="12" cy="13" r="3.4" /></>, {color, strokeWidth});

export const GearIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor', strokeWidth = 2}) =>
  base(size, <><circle cx="12" cy="12" r="3.2" /><path d="M12 2.8v3M12 18.2v3M2.8 12h3M18.2 12h3M5.5 5.5l2.1 2.1M16.4 16.4l2.1 2.1M18.5 5.5l-2.1 2.1M7.6 16.4l-2.1 2.1" /></>, {color, strokeWidth});

export const PrevIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor'}) =>
  base(size, <><path d="M19 5v14L9.5 12Z" /><rect x="5" y="5" width="2.4" height="14" rx="1" /></>, {color, strokeWidth: 0, filled: true});

export const NextIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor'}) =>
  base(size, <><path d="M5 5v14l9.5-7Z" /><rect x="16.6" y="5" width="2.4" height="14" rx="1" /></>, {color, strokeWidth: 0, filled: true});

export const PauseIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor'}) =>
  base(size, <><rect x="6" y="4.5" width="4" height="15" rx="1.4" /><rect x="14" y="4.5" width="4" height="15" rx="1.4" /></>, {color, strokeWidth: 0, filled: true});

export const PlayIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor'}) =>
  base(size, <path d="M7 4.5v15L20 12Z" />, {color, strokeWidth: 0, filled: true});

export const KeyboardIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor', strokeWidth = 2}) =>
  base(size, <><rect x="2.5" y="7" width="19" height="11" rx="2" /><path d="M6 10.5h.01M9.5 10.5h.01M13 10.5h.01M16.5 10.5h.01M7 14.5h10" /></>, {color, strokeWidth});

export const MoonIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor', strokeWidth = 2}) =>
  base(size, <path d="M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5Z" />, {color, strokeWidth});

export const PresenterIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor', strokeWidth = 2}) =>
  base(size, <><circle cx="10" cy="8" r="3.2" /><path d="M4.5 20a5.5 5.5 0 0 1 11 0" /><path d="M17.5 6.5a5 5 0 0 1 0 6M20 4.5a8 8 0 0 1 0 10" /></>, {color, strokeWidth});

export const EyedropperIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor', strokeWidth = 2}) =>
  base(size, <><path d="m13.5 7 3.5 3.5" /><path d="M15.5 5 19 8.5l1.6-1.6a2.47 2.47 0 0 0-3.5-3.5Z" /><path d="M14.5 8.5 6 17l-1.5 4L8.5 19.5 17 11" /></>, {color, strokeWidth});

export const PinIcon: React.FC<IconProps> = ({size = 12, color = 'currentColor', strokeWidth = 2}) =>
  base(size, <><path d="M9 4h6l-1 6 3 3v1.5H7V13l3-3Z" /><path d="M12 14.5V21" /></>, {color, strokeWidth});

export const TrashIcon: React.FC<IconProps> = ({size = 12, color = 'currentColor', strokeWidth = 2}) =>
  base(size, <><path d="M4.5 6.5h15" /><path d="M8 6.5V5a1.5 1.5 0 0 1 1.5-1.5h5A1.5 1.5 0 0 1 16 5v1.5" /><path d="M6.5 6.5 7.5 20h9l1-13.5" /><path d="M10 10.5v6M14 10.5v6" /></>, {color, strokeWidth});

export const MicIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor', strokeWidth = 2}) =>
  base(size, <><rect x="9" y="3" width="6" height="11" rx="3" /><path d="M5.5 11.5a6.5 6.5 0 0 0 13 0" /><path d="M12 18v3" /></>, {color, strokeWidth});

export const BoltIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor'}) =>
  base(size, <path d="M13 2 5 13.5h5.5L11 22l8-11.5h-5.5Z" />, {color, strokeWidth: 0, filled: true});

export const BatteryIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor', strokeWidth = 2}) =>
  base(size, <><rect x="2.5" y="8" width="16" height="8" rx="2" /><path d="M21.5 11v2" /><rect x="4.5" y="10" width="9" height="4" rx="1" fill={color} stroke="none" /></>, {color, strokeWidth});

export const ChipIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor', strokeWidth = 2}) =>
  base(size, <><rect x="7" y="7" width="10" height="10" rx="1.5" /><path d="M10 3.5V7M14 3.5V7M10 17v3.5M14 17v3.5M3.5 10H7M3.5 14H7M17 10h3.5M17 14h3.5" /></>, {color, strokeWidth});

export const AppleIcon: React.FC<IconProps> = ({size = 14, color = 'currentColor'}) =>
  base(size, <path d="M16.365 1.43c0 1.14-.42 2.23-1.24 3.05-.83.83-2.19 1.45-3.31 1.36-.14-1.1.43-2.24 1.2-2.98.85-.83 2.32-1.42 3.35-1.43zM20.5 17.29c-.57 1.31-.85 1.9-1.59 3.06-1.03 1.61-2.48 3.62-4.28 3.63-1.6.01-2.01-1.05-4.18-1.04-2.17.01-2.62 1.06-4.22 1.05-1.8-.02-3.18-1.83-4.21-3.44C-.36 16.72-1.02 10.6 2.87 8.4c1.4-.8 2.86-1.24 4.24-1.26 1.61-.03 3.13 1.09 4.19 1.09 1.05 0 2.87-1.35 4.85-1.15.83.03 3.16.33 4.66 2.52-.12.08-2.78 1.62-2.75 4.82.03 3.83 3.36 5.1 3.4 5.11-.03.09-.53 1.82-1.96 3.76z" />, {color, strokeWidth: 0, filled: true});
