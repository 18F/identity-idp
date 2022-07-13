import type { ReactNode } from 'react';

interface ProcessListHeadingProps {
  children?: ReactNode;

  // pass unstyled to render unstyled text
  unstyled?: boolean;
}

function ProcessListHeading({ children, unstyled }: ProcessListHeadingProps) {
  const headingClass = unstyled === true ? undefined : 'usa-process-list__heading';
  const classes = [headingClass].filter(Boolean).join(' ');

  return <p className={classes}>{children}</p>;
}

export default ProcessListHeading;
