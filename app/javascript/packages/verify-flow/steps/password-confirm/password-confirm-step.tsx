import type { ChangeEvent } from 'react';
import { PasswordToggle } from '@18f/identity-password-toggle';
import { FormStepsButton } from '@18f/identity-form-steps';
import { Alert } from '@18f/identity-components';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import StartOverOrCancel from '../../start-over-or-cancel';
import type { VerifyFlowValues } from '../../verify-flow';

interface PasswordConfirmStepStepProps extends FormStepComponentProps<VerifyFlowValues> {}

function PasswordConfirmStep({ errors, registerField, onChange }: PasswordConfirmStepStepProps) {
  return (
    <>
      {errors.map(({ error }) => (
        <Alert key={error.message} type="error" className="margin-bottom-4">
          {error.message}
        </Alert>
      ))}
      <PasswordToggle
        ref={registerField('password')}
        type="password"
        onInput={(event: ChangeEvent<HTMLInputElement>) => {
          onChange({ password: event.target.value });
        }}
      />
      <FormStepsButton.Continue />
      <StartOverOrCancel />
    </>
  );
}

export default PasswordConfirmStep;
