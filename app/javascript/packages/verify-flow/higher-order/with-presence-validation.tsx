import { useEffect } from 'react';
import type { ComponentType } from 'react';
import type { FormStepComponentProps } from '@18f/identity-form-steps';

/**
 * Higher order component which confirms that the specified keys are present in the form step value,
 * else returns the user to the previous step.
 *
 * @param Component Original step component implementation.
 * @param keys Steps to validate.
 *
 * @return Enhanced component.
 */
const withPresenceValidation =
  <P extends FormStepComponentProps<any>, K extends keyof P['value']>(
    Component: ComponentType<P>,
    ...keys: K[]
  ): ComponentType<P & { value: { [key in K]?: P[key] } }> =>
  (props: P) => {
    const { value, toPreviousStep } = props;
    const isValid = keys.every((key) => value[key] !== undefined);
    useEffect(() => {
      if (!isValid) {
        toPreviousStep();
      }
    }, [isValid]);

    return isValid ? <Component {...props} /> : null;
  };

export default withPresenceValidation;
