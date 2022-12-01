import { forwardRef } from 'react';
import type { InputHTMLAttributes, ForwardedRef } from 'react';
import { useInstanceId } from '@18f/identity-react-hooks';

export interface TextInputProps extends InputHTMLAttributes<HTMLInputElement> {
  /**
   * Text of label associated with input.
   */
  label: string;

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
  { label, id, className, ...inputProps }: TextInputProps,
  ref: ForwardedRef<HTMLInputElement>,
) {
  const instanceId = useInstanceId();
  const inputId = id ?? `text-input-${instanceId}`;
  const classes = ['usa-input', className].filter(Boolean).join(' ');

  return (
    <>
      <label className="usa-label" htmlFor={inputId}>
        {label}
      </label>
      <input ref={ref} className={classes} id={inputId} {...inputProps} />
    </>
  );
}

export default forwardRef(TextInput);
