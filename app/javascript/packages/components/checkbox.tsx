import type { InputHTMLAttributes } from 'react';
import { useInstanceId } from '@18f/identity-react-hooks';

export interface CheckboxProps extends InputHTMLAttributes<HTMLInputElement> {
  isTitle?: boolean;
  id?: string;
  className?: string;
  label: string;
  labelDescription?: string;
  /**
   * Muted explainer text sitting below the label.
   */
  hint?: string;
}

function Checkbox({
  id,
  isTitle,
  className,
  label,
  labelDescription,
  hint,
  ...inputProps
}: CheckboxProps) {
  const instanceId = useInstanceId();
  const inputId = id ?? `checkbox-input-${instanceId}`;
  const hintId = id ?? `select-input-hint-${instanceId}`;
  const classes = ['usa-checkbox__input', isTitle && 'usa-button__input-title', className]
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
