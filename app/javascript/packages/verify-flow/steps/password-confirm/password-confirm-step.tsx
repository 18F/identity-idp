import type { ChangeEvent } from 'react';
import { t } from '@18f/identity-i18n';
import { FormStepsButton } from '@18f/identity-form-steps';
import { Alert } from '@18f/identity-components';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
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
      <input
        ref={registerField('password')}
        aria-label={t('idv.form.password')}
        type="password"
        onInput={(event: ChangeEvent<HTMLInputElement>) => {
          onChange({ password: event.target.value });
        }}
      />
      <FormStepsButton.Continue />
    </>
  );
}

export default PasswordConfirmStep;
