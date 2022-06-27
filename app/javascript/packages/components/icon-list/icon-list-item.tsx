import type { ReactNode } from 'react';

interface IconListItemProps {
  children?: ReactNode;

  className?: string;
}

function IconListItem({ children, className }: IconListItemProps) {
  const classes = ['usa-icon-list__item', className].filter(Boolean).join(' ');

  return <li className={classes}>{children}</li>;
}

export default IconListItem;
