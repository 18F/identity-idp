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

  /**
   * Whether or not the child elements should go directly into the alert body (rather than the single p element)
   * Optional and defaults to false
   */
  body?: boolean;
}

function Alert(
  { type = 'other', className, isFocusable, children, body = false }: AlertProps,
  ref: ForwardedRef<any>,
) {
  const classes = [`usa-alert usa-alert--${type}`, className].filter(Boolean).join(' ');
  const role = type === 'error' ? 'alert' : 'status';

  let inner: Element | ReactNode = <p className="usa-alert__text">{children}</p>;
  if (body) {
    inner = children;
  }

  return (
    <div ref={ref} className={classes} role={role} tabIndex={isFocusable ? -1 : undefined}>
      <div className="usa-alert__body">{inner}</div>
    </div>
  );
}

export default forwardRef(Alert);
