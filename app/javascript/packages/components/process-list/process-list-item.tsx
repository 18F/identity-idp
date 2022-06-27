import type { ReactNode } from 'react';

interface ProcessListItemProps {
  className?: string;

  children?: ReactNode;
}

function ProcessListItem({ children, className }: ProcessListItemProps) {
  const classes = ['usa-process-list__item', className].filter(Boolean).join(' ');

  return <li className={classes}>{children}</li>;
}

export default ProcessListItem;
