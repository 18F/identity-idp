import { useRef, useEffect, Children, cloneElement, createElement } from 'react';
import type { MutableRefObject, ReactNode, HTMLAttributes, ReactHTMLElement } from 'react';
import { useInstanceId } from '@18f/identity-react-hooks';
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

function ValidatedField({
  validate = () => {},
  children,
  ...inputProps
}: ValidatedFieldProps & HTMLAttributes<HTMLInputElement>) {
  const fieldRef = useRef<ValidatedFieldElement>();
  const instanceId = useInstanceId();
  useEffect(() => {
    fieldRef.current!.validate = () => {
      const input = fieldRef.current!.input!;

      let nextError: string = '';
      try {
        validate(input.value);
      } catch (error) {
        nextError = error.message;
      }

      input.setCustomValidity(nextError);
    };
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

export default ValidatedField;
