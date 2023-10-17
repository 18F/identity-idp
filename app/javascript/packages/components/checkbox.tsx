import type { InputHTMLAttributes } from 'react';
import { useInstanceId } from '@18f/identity-react-hooks';

export interface CheckboxProps extends InputHTMLAttributes<HTMLInputElement> {
  /**
   * Whether checkbox is considered title, a box around it, with optional description for the label
   */
  isTitle?: boolean;
  /**
   * Whether is focused, a focus box around the checkbox
   */
  isFocus?: boolean;
  /**
   * Optional id for the element
   */
  id?: string;
  /**
   * Optional additional class names.
   */
  className?: string;
  /**
   * Label text for the checkbox
   */
  label: string;
  /**
   * Optional description for the label, used with isTitle
   */
  labelDescription?: string;
  /**
   * Muted explainer text sitting below the label.
   */
  hint?: string;
}

function Checkbox({
  id,
  isTitle,
  isFocus,
  className,
  label,
  labelDescription,
  hint,
  ...inputProps
}: CheckboxProps) {
  const instanceId = useInstanceId();
  const inputId = id ?? `check-input-${instanceId}`;
  const hintId = id ?? `check-input-hint-${instanceId}`;
  const classes = [
    'usa-checkbox__input',
    isTitle && 'usa-button__input-title',
    isFocus && 'usa-focus',
    className,
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <div className="usa-checkbox">
      <input id={inputId} className={classes} type="checkbox" {...inputProps} />
      <label className="usa-checkbox__label" htmlFor={inputId}>
        {label}
        {labelDescription && (
          <span className="usa-checkbox__label-description">{labelDescription}</span>
        )}
      </label>
      {hint && (
        <div id={hintId} className="usa-hint">
          {hint}
        </div>
      )}
    </div>
  );
}
export default Checkbox;
