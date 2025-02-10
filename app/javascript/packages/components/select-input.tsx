import { forwardRef } from 'react';
import type { InputHTMLAttributes, ForwardedRef } from 'react';
import { useInstanceId } from '@18f/identity-react-hooks';

export interface SelectInputProps extends InputHTMLAttributes<HTMLSelectElement> {
  /**
   * Text of label associated with input.
   */
  label: string;

  /**
   * Muted explainer text sitting below the label.
   */
  hint?: string;

  /**
   * Optional explicit ID to use in place of default behavior.
   */
  id?: string;

  /**
   * Additional class name to be applied to the input element.
   */
  className?: string;

  /**
   * Child elements
   */
  children: React.ReactNode;
}

function SelectInput(
  { label, hint, id, className, children, ...inputProps }: SelectInputProps,
  ref: ForwardedRef<HTMLSelectElement>,
) {
  const instanceId = useInstanceId();
  const inputId = id ?? `select-input-${instanceId}`;
  const hintId = id ?? `select-input-hint-${instanceId}`;
  const classes = ['usa-select', className].filter(Boolean).join(' ');

  return (
    <>
      <label className="usa-label" htmlFor={inputId}>
        {label}
      </label>
      {hint && (
        <div id={hintId} className="usa-hint">
          {hint}
        </div>
      )}
      <select
        ref={ref}
        className={classes}
        id={inputId}
        aria-describedby={hint && hintId}
        {...inputProps}
      >
        {children}
      </select>
    </>
  );
}

export default forwardRef(SelectInput);
