/** @typedef {import('react').MouseEvent} ReactMouseEvent */
/** @typedef {import('react').ReactNode} ReactNode */
/** @typedef {"button"|"reset"|"submit"} ButtonType */

/**
 * @typedef ButtonProps
 *
 * @prop {ButtonType=} type Button type, defaulting to "button".
 * @prop {(ReactMouseEvent)=>void=} onClick Click handler.
 * @prop {ReactNode=} children Element children.
 * @prop {boolean=} isWide Whether button should be styled as primary button.
 * @prop {boolean=} isOutline Whether button should be styled as secondary button.
 * @prop {boolean=} isDisabled Whether button is disabled.
 * @prop {boolean=} isUnstyled Whether button should be unstyled, visually as a link.
 * @prop {boolean=} isVisuallyDisabled Whether button should appear disabled (but remain clickable).
 * @prop {string=} className Optional additional class names.
 */

/**
 * @param {ButtonProps} props Props object.
 */
function Button({
  type = 'button',
  onClick,
  children,
  isWide,
  isOutline,
  isDisabled,
  isUnstyled,
  isVisuallyDisabled,
  className,
}) {
  const classes = [
    'btn',
    isWide && 'btn-wide',
    !isOutline && !isUnstyled && 'btn-primary',
    isOutline && 'btn-secondary',
    isUnstyled && 'btn-link',
    isVisuallyDisabled && 'btn-disabled',
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
