import {
  useRef,
  useEffect,
  Children,
  cloneElement,
  createElement,
  useImperativeHandle,
  forwardRef,
} from 'react';
import type {
  MutableRefObject,
  ReactNode,
  HTMLAttributes,
  InputHTMLAttributes,
  ReactHTMLElement,
} from 'react';
import { useInstanceId } from '@18f/identity-react-hooks';
import { t } from '@18f/identity-i18n';
import './validated-field-element';
import type ValidatedFieldElement from './validated-field-element';

export type ValidatedFieldValidator = (value: string) => void;

interface ValidatedFieldProps {
  /**
   * Callback to check validity of the current value, throwing an error with the message to be shown
   * if invalid.
   */
  validate?: ValidatedFieldValidator;

  /**
   * Optional key and value that indicates the error and resulting error message
   */
  messages?: Record<string, string>;

  /**
   * Optional input to use in place of the default rendered input. The input will be cloned and
   * extended with behaviors for validation.
   */
  children?: ReactNode;
}

declare global {
  namespace JSX {
    interface IntrinsicElements {
      'lg-validated-field': HTMLAttributes<ValidatedFieldElement> & {
        class?: string;
        ref?: MutableRefObject<ValidatedFieldElement | undefined>;
      };
    }
  }
}

/**
 * Returns validity string error messages according to the given input type.
 */
export function getErrorMessages(inputType?: string) {
  const messages: Partial<Record<keyof ValidityState, string>> = {
    valueMissing:
      inputType === 'checkbox'
        ? t('forms.validation.required_checkbox')
        : t('simple_form.required.text'),
  };

  if (inputType === 'email') {
    messages.typeMismatch = t('valid_email.validations.email.invalid');
  }

  return messages;
}

function ValidatedField(
  {
    validate = () => {},
    messages,
    children,
    ...inputProps
  }: ValidatedFieldProps & InputHTMLAttributes<HTMLInputElement>,
  forwardedRef,
) {
  const fieldRef = useRef<ValidatedFieldElement>();
  const instanceId = useInstanceId();
  // WILLFIX: we shouldn't be returning the HTML input child below as it could
  //          result in a stale reference. This will be fixed with LG-8494
  useImperativeHandle(forwardedRef, () => fieldRef.current?.input);
  useEffect(() => {
    if (fieldRef.current && fieldRef.current.input) {
      const { input } = fieldRef.current;
      input.checkValidity = () => {
        let nextError: string = '';
        try {
          validate(input.value);
        } catch (error) {
          nextError = error.message;
        }
        // this is here in case the component validation state changes during the validate call
        nextError = nextError || (input.validity.customError && input.validationMessage) || '';

        input.setCustomValidity(nextError);
        return !nextError && HTMLInputElement.prototype.checkValidity.call(input);
      };

      input.reportValidity = () => {
        input.checkValidity();
        return HTMLInputElement.prototype.reportValidity.call(input);
      };
    }
  }, [validate]);

  const errorId = `validated-field-error-${instanceId}`;

  const input: ReactHTMLElement<HTMLInputElement> = children
    ? (Children.only(children) as ReactHTMLElement<HTMLInputElement>)
    : createElement('input');

  const inputClasses = ['validated-field__input', inputProps.className, input.props.className]
    .filter(Boolean)
    .join(' ');

  return (
    <lg-validated-field ref={fieldRef} error-id={errorId}>
      <script type="application/json" className="validated-field__error-strings">
        {JSON.stringify({ ...getErrorMessages(inputProps.type), ...messages })}
      </script>
      <div className="validated-field__input-wrapper">
        {cloneElement(input, {
          ...inputProps,
          'aria-invalid': false,
          className: inputClasses,
        })}
      </div>
    </lg-validated-field>
  );
}

export default forwardRef(ValidatedField);
