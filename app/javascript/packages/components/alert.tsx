import { forwardRef } from 'react';
import type { ReactNode, ForwardedRef } from 'react';

export type AlertType = 'success' | 'warning' | 'error' | 'info' | 'other';

interface AlertProps {
  /**
   * Alert type. Defaults to "other".
   */
  type?: AlertType;

  /**
   * Optional additional class names to add to element.
   */
  className?: string;

  /**
   * Optional, whether rendered element should be focusable, as in the case where focus should be shifted programmatically to a new alert.
   */
  isFocusable?: boolean;

  /**
   * Child elements.
   */
  children?: ReactNode;
}

function Alert(
  { type = 'other', className, isFocusable, children }: AlertProps,
  ref: ForwardedRef<any>,
) {
  const classes = [`usa-alert usa-alert--${type}`, className].filter(Boolean).join(' ');
  const role = type === 'error' ? 'alert' : 'status';

  return (
    <div ref={ref} className={classes} role={role} tabIndex={isFocusable ? -1 : undefined}>
      <div className="usa-alert__body">
        <p className="usa-alert__text">{children}</p>
      </div>
    </div>
  );
}

export default forwardRef(Alert);
