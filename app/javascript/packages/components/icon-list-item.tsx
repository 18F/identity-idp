import { forwardRef } from 'react';
import type { ReactNode } from 'react';

interface IconListItemProps extends Record<string, any> {
  children?: ReactNode;

  className?: string;
}

function IconListItem({ children, className }: IconListItemProps, ref) {
  const classes = ['usa-icon-list__item', className].filter(Boolean).join(' ');

  return (
    <li ref={ref} className={classes}>
      {children}
    </li>
  );
}

export default forwardRef(IconListItem);
