import type { ReactNode } from 'react';

interface IconListContentProps {
  children?: ReactNode;

  className?: string;
}

function IconListContent({ children, className }: IconListContentProps) {
  const classes = ['usa-icon-list__content', className].filter(Boolean).join(' ');

  return <div className={classes}>{children}</div>;
}

export default IconListContent;
