import type { ReactNode } from 'react';

interface IconListIconProps {
  children?: ReactNode;

  className?: string;
}

function IconListIcon({ children, className }: IconListIconProps) {
  const classes = ['usa-icon-list__icon', className].filter(Boolean).join(' ');

  return <div className={classes}>{children}</div>;
}

export default IconListIcon;
