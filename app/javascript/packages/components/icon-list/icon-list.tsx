import type { ReactNode } from 'react';

interface IconListProps {
  children?: ReactNode;

  className?: string;
}

function IconList({ children, className }: IconListProps) {
  const classes = ['usa-icon-list', className].filter(Boolean).join(' ');

  return <ul className={classes}>{children}</ul>;
}

export default IconList;
