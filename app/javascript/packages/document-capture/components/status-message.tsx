import type { ReactNode } from 'react';

export enum Status {
  ERROR = 'ERROR',
  SUCCESS = 'SUCCESS',
}

interface StatusMessageProps {
  status: Status;
  className?: string;
  children?: ReactNode;
}

function StatusMessage({ status, className, children }: StatusMessageProps) {
  const classes = [
    status === Status.ERROR && 'usa-error-message',
    status === Status.SUCCESS && 'usa-success-message',
    !children && 'display-none',
    className,
  ]
    .filter(Boolean)
    .join(' ');

  const role = status === Status.ERROR ? 'alert' : 'status';

  return (
    <span role={role} className={classes} aria-live="polite">
      {children}
    </span>
  );
}

export default StatusMessage;
