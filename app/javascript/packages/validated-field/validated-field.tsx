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
  useImperativeHandle(forwardedRef, () => ({
    reportValidity: () => fieldRef.current.input.reportValidity(),
  }));
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
    <lg-validated-field ref={fieldRef}>
      <script type="application/json" className="validated-field__error-strings">
        {JSON.stringify({ ...getErrorMessages(messages, inputProps.type), ...messages })}
      </script>
      <div className="validated-field__input-wrapper">
        {cloneElement(input, {
          ...inputProps,
          'aria-invalid': false,
          'aria-describedby': errorId,
          className: inputClasses,
        })}
      </div>
    </lg-validated-field>
  );
}

export default forwardRef(ValidatedField);
