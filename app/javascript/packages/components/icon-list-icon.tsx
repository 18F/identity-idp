import { forwardRef } from 'react';
import type { ReactNode } from 'react';

interface IconListIconProps extends Record<string, any> {
  children?: ReactNode;

  className?: string;
}

function IconListIcon({ children, className }: IconListIconProps, ref) {
  const classes = ['usa-icon-list__icon', className].filter(Boolean).join(' ');

  return (
    <div ref={ref} className={classes}>
      {children}
    </div>
  );
}

export default forwardRef(IconListIcon);
