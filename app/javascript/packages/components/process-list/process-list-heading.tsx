import { forwardRef } from 'react';
import type { ReactNode } from 'react';

interface ProcessListHeadingProps extends Record<string, any> {
  children?: ReactNode;

  className?: string;

  // pass unstyled to render unstyled text
  unstyled?: boolean;
}

function ProcessListHeading({ children, className, unstyled }: ProcessListHeadingProps, ref) {
  const headingClass = unstyled === true ? undefined : 'usa-process-list__heading';
  const noClasses = headingClass === undefined && className === undefined;
  const classes = noClasses ? undefined : [headingClass, className].filter(Boolean).join(' ');

  return (
    <p ref={ref} className={classes}>
      {children}
    </p>
  );
}

export default forwardRef(ProcessListHeading);
