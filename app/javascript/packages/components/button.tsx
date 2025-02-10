import { createElement } from 'react';
import type { AnchorHTMLAttributes, ButtonHTMLAttributes, MouseEvent, ReactNode } from 'react';

type ButtonType = 'button' | 'reset' | 'submit';

export interface ButtonProps {
  /**
   * Button type, defaulting to "button".
   */
  type?: ButtonType;

  /**
   * For a link styled as a button, the destination of the link.
   */
  href?: string;

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
  href,
  type = href ? undefined : 'button',
  children,
  isBig,
  isFlexibleWidth,
  isWide,
  isOutline,
  isDisabled,
  isUnstyled,
  className,
  ...htmlAttributes
}: ButtonProps &
  AnchorHTMLAttributes<HTMLAnchorElement> &
  ButtonHTMLAttributes<HTMLButtonElement>) {
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

  const tagName = href ? 'a' : 'button';

  return createElement(
    tagName,
    { type, href, disabled: isDisabled, className: classes, ...htmlAttributes },
    children,
  );
}

export default Button;
