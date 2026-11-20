import { forwardRef, useState } from 'react';
import type { ForwardedRef, InputHTMLAttributes, MutableRefObject, RefObject } from 'react';
import { useInstanceId } from '@18f/identity-react-hooks';
import { t } from '@18f/identity-i18n';

interface NDSTextInputProps extends InputHTMLAttributes<HTMLInputElement> {
  /**
   * Text of the label, also shown as the floating label inside the field.
   */
  label: string;

  /**
   * Error messages keyed by validity state, like ValidatedField's `messages`.
   */
  messages?: Partial<Record<keyof ValidityState, string>>;

  /**
   * Additional ref assigned the input element, alongside the forwarded ref.
   */
  fieldRef?: RefObject<HTMLInputElement>;
}

/**
 * NDS floating-label text input. Emits the markup contract of `NDS::InputComponent` (a
 * `.usa-input` wrapper with a visually hidden label, a `.usa-input__shell` holding the
 * `.usa-input__control--floating` input and its aria-hidden `.usa-input__floating-label`, and a
 * `.usa-input__error` region), so the design system styles it the same as the server-rendered NDS
 * inputs.
 *
 * Like ValidatedField does for the default markup, constraint validation errors render inline
 * instead of as the browser's bubble: an `invalid` event (from `reportValidity()`, or from leaving
 * a field that has a value) shows the message below the field, and typing clears it.
 */
function NDSTextInput(
  {
    label,
    messages = {},
    fieldRef,
    id,
    className,
    onBlur,
    onInput,
    ...inputProps
  }: NDSTextInputProps,
  ref: ForwardedRef<HTMLInputElement>,
) {
  const instanceId = useInstanceId();
  const inputId = id ?? `nds-text-input-${instanceId}`;
  const errorId = `${inputId}-error`;
  const [error, setError] = useState('');

  function setRefs(element: HTMLInputElement | null) {
    if (typeof ref === 'function') {
      ref(element);
    } else if (ref) {
      ref.current = element;
    }
    if (fieldRef) {
      (fieldRef as MutableRefObject<HTMLInputElement | null>).current = element;
    }
  }

  function getMessage(input: HTMLInputElement): string {
    if (input.validity.valid) {
      return '';
    }

    const strings = { valueMissing: t('simple_form.required.text'), ...messages };
    for (const type in input.validity) {
      if (type !== 'valid' && input.validity[type] && strings[type]) {
        return strings[type];
      }
    }

    return input.validationMessage;
  }

  const controlClasses = ['usa-input__control', 'usa-input__control--floating', className]
    .filter(Boolean)
    .join(' ');

  return (
    <div className="usa-input">
      <label className="usa-input__label" htmlFor={inputId}>
        {label}
      </label>
      <div className="usa-input__shell">
        <input
          {...inputProps}
          ref={setRefs}
          id={inputId}
          className={controlClasses}
          placeholder=" "
          aria-invalid={!!error}
          aria-describedby={error ? errorId : undefined}
          onInvalid={(event) => {
            event.preventDefault();
            setError(getMessage(event.currentTarget));
          }}
          onInput={(event) => {
            setError('');
            onInput?.(event);
          }}
          onBlur={(event) => {
            if (event.currentTarget.value) {
              event.currentTarget.checkValidity();
            }
            onBlur?.(event);
          }}
        />
        <span className="usa-input__floating-label" aria-hidden="true">
          {label}
        </span>
      </div>
      <p
        id={errorId}
        className={['usa-input__error', error && 'usa-input__error--visible']
          .filter(Boolean)
          .join(' ')}
        aria-live="polite"
      >
        <span className="usa-input__error-inner">{error}</span>
      </p>
    </div>
  );
}

export default forwardRef(NDSTextInput);
