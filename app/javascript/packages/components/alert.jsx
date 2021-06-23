import { forwardRef } from 'react';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef {"success"|"warning"|"error"|"info"|"other"} AlertType
 */

/**
 * @typedef AlertProps
 *
 * @prop {AlertType=} type Alert type. Defaults to "other".
 * @prop {string=} className Optional additional class names to add to element.
 * @prop {ReactNode} children Child elements.
 */

/**
 * @param {AlertProps} props Props object.
 * @param {import('react').ForwardedRef<any>} ref
 */
function Alert({ type = 'other', className, children }, ref) {
  const classes = [`usa-alert usa-alert--${type}`, className].filter(Boolean).join(' ');

  return (
    <div ref={ref} className={classes} role="alert">
      <div className="usa-alert__body">
        <p className="usa-alert__text">{children}</p>
      </div>
    </div>
  );
}

export default forwardRef(Alert);
