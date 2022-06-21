import { forwardRef } from 'react';
import type { ReactNode } from 'react';

interface ProcessListProps extends Record<string, any> {
  className?: string;

  children?: ReactNode;
}

function ProcessList({ children, className }: ProcessListProps, ref) {
  const classes = ['usa-process-list', className].filter(Boolean).join(' ');

  return (
    <ol ref={ref} className={classes}>
      {children}
    </ol>
  );
}

export default forwardRef(ProcessList);
