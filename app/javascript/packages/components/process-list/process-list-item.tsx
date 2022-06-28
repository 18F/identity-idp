import { ProcessListHeading } from '@18f/identity-components';
import type { ReactNode } from 'react';

interface ProcessListItemProps {
  className?: string;

  children?: ReactNode;

  heading: string;

  headingUnstyled?: boolean;
}

function ProcessListItem({ children, className, heading, headingUnstyled }: ProcessListItemProps) {
  const classes = ['usa-process-list__item', className].filter(Boolean).join(' ');

  return (
    <li className={classes}>
      <ProcessListHeading unstyled={headingUnstyled}>{heading}</ProcessListHeading>
      {children}
    </li>
  );
}

export default ProcessListItem;
