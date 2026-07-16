import { forwardRef, createElement } from 'react';
import type { ReactNode, ForwardedRef } from 'react';

export type AlertType = 'success' | 'warning' | 'error' | 'info';

interface AlertProps {
  /**
   * Alert type.
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
   * Which tag to use for the alert text element.
   * Optional and defaults to p
   */
  textTag?: string;
}

const TYPE_CLASS: Record<AlertType, string> = {
  success: 'ads-alert--success',
  warning: 'ads-alert--warning',
  error: 'ads-alert--error',
  info: 'ads-alert--neutral',
};

function Alert(
  { type, className, isFocusable, children, textTag = 'p' }: AlertProps,
  ref: ForwardedRef<any>,
) {
  const classes = ['ads-alert', type && TYPE_CLASS[type], className].filter(Boolean).join(' ');
  const role = type === 'error' ? 'alert' : 'status';

  const inner = createElement(textTag, { className: 'ads-alert__text' }, children);

  return (
    <div ref={ref} className={classes} role={role} tabIndex={isFocusable ? -1 : undefined}>
      {inner}
    </div>
  );
}

export default forwardRef(Alert);
