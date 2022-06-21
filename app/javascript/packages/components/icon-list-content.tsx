import { forwardRef } from 'react';
import type { ReactNode } from 'react';

interface IconListContentProps extends Record<string, any> {
  children?: ReactNode;

  className?: string;
}

function IconListContent({ children, className }: IconListContentProps, ref) {
  const classes = ['usa-icon-list__content', className].filter(Boolean).join(' ');

  return (
    <div ref={ref} className={classes}>
      {children}
    </div>
  );
}

export default forwardRef(IconListContent);
