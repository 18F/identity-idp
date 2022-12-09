import { forwardRef } from 'react';
import type { InputHTMLAttributes, ForwardedRef } from 'react';
import { useInstanceId } from '@18f/identity-react-hooks';

export interface TextInputProps extends InputHTMLAttributes<HTMLInputElement> {
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
}

function TextInput(
  { label, hint, id, className, ...inputProps }: TextInputProps,
  ref: ForwardedRef<HTMLInputElement>,
) {
  const instanceId = useInstanceId();
  const inputId = id ?? `text-input-${instanceId}`;
  const hintId = id ?? `text-input-hint-${instanceId}`;
  const classes = ['usa-input', className].filter(Boolean).join(' ');

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
      <input aria-describedby={hintId} ref={ref} className={classes} id={inputId} {...inputProps} />
    </>
  );
}

export default forwardRef(TextInput);
