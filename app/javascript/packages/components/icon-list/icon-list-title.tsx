import { forwardRef } from 'react';
import type { ReactNode } from 'react';

interface IconListTitleProps extends Record<string, any> {
  children?: ReactNode;

  className?: string;
}

function IconListTitle({ children, className }: IconListTitleProps, ref) {
  const classes = ['usa-icon-list__title', className].filter(Boolean).join(' ');

  return (
    <h4 ref={ref} className={classes}>
      {children}
    </h4>
  );
}

export default forwardRef(IconListTitle);
