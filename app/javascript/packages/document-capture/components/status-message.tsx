import type { ReactNode } from 'react';

export enum Status {
  ERROR = 'ERROR',
  SUCCESS = 'SUCCESS',
}

function StatusMessage({
  status,
  className,
  children,
}: {
  status: Status;
  className?: string;
  children?: ReactNode;
}) {
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
    <span role={role} className={classes}>
      {children}
    </span>
  );
}

export default StatusMessage;
