import type { MouseEvent, ReactNode } from 'react';

type ButtonType = 'button' | 'reset' | 'submit';

export interface ButtonProps {
  /**
   * Button type, defaulting to "button".
   */
  type?: ButtonType;

  /**
   * Click handler.
   */
  onClick?: (event: MouseEvent) => void;

  /**
   * Element children.
   */
  children?: ReactNode;

  /**
   * Whether button should be styled as big button.
   */
  isBig?: boolean;

  /**
   * Whether button should be styled as flexible width, such that it shrinks to its minimum width instead of occupying full-width on mobile viewports.
   */
  isFlexibleWidth?: boolean;

  /**
   * Whether button should be styled as primary button.
   */
  isWide?: boolean;

  /**
   * Whether button should be styled as secondary button.
   */
  isOutline?: boolean;

  /**
   * Whether button is disabled.
   */
  isDisabled?: boolean;

  /**
   * Whether button should be unstyled, visually as a link.
   */
  isUnstyled?: boolean;

  /**
   * Optional additional class names.
   */
  className?: string;
}

function Button({
  type = 'button',
  onClick,
  children,
  isBig,
  isFlexibleWidth,
  isWide,
  isOutline,
  isDisabled,
  isUnstyled,
  className,
}: ButtonProps) {
  const classes = [
    'usa-button',
    isBig && 'usa-button--big',
    isFlexibleWidth && 'usa-button--flexible-width',
    isWide && 'usa-button--wide',
    isOutline && 'usa-button--outline',
    isUnstyled && 'usa-button--unstyled',
    className,
  ]
    .filter(Boolean)
    .join(' ');

  return (
    // Disable reason: We can assume `type` is provided as valid, or the default `button`.
    // eslint-disable-next-line react/button-has-type
    <button type={type} onClick={onClick} disabled={isDisabled} className={classes}>
      {children}
    </button>
  );
}

export default Button;
