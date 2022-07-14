import { ProcessListHeading } from '@18f/identity-components';
import type { ReactNode } from 'react';

interface ProcessListItemProps {
  children?: ReactNode;

  heading: string;

  headingUnstyled?: boolean;
}

function ProcessListItem({ children, heading, headingUnstyled }: ProcessListItemProps) {
  const classes = 'usa-process-list__item';

  return (
    <li className={classes}>
      <ProcessListHeading unstyled={headingUnstyled}>{heading}</ProcessListHeading>
      {children}
    </li>
  );
}

export default ProcessListItem;
