import type { ReactNode } from 'react';

interface ProcessListProps {
  className?: string;

  children?: ReactNode;
}

function ProcessList({ children, className }: ProcessListProps) {
  const classes = ['usa-process-list', className].filter(Boolean).join(' ');

  return <ol className={classes}>{children}</ol>;
}

export default ProcessList;
