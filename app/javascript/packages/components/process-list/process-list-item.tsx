import { forwardRef } from 'react';
import type { ReactNode } from 'react';

interface ProcessListItemProps extends Record<string, any> {
  className?: string;

  children?: ReactNode;
}

function ProcessListItem({ children, className }: ProcessListItemProps, ref) {
  const classes = ['usa-process-list__item', className].filter(Boolean).join(' ');

  return (
    <li ref={ref} className={classes}>
      {children}
    </li>
  );
}

export default forwardRef(ProcessListItem);
