import { forwardRef } from 'react';
import type { ReactNode } from 'react';

interface IconListProps extends Record<string, any> {
  children?: ReactNode;

  className?: string;
}

function IconList({ children, className }: IconListProps, ref) {
  const classes = ['usa-icon-list', className].filter(Boolean).join(' ');

  return (
    <ul ref={ref} className={classes}>
      {children}
    </ul>
  );
}

export default forwardRef(IconList);
