/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @enum {string}
 */
export const Status = {
  ERROR: 'ERROR',
  SUCCESS: 'SUCCESS',
};

/**
 * @typedef StatusMessageProps
 *
 * @prop {Status} status
 * @prop {string=} className
 * @prop {ReactNode=} children
 */

/**
 * @param {StatusMessageProps} props
 */
function StatusMessage({ status, className, children }) {
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
