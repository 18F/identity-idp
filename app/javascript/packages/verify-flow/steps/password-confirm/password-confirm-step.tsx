import type { ChangeEvent } from 'react';
import { t } from '@18f/identity-i18n';
import { FormStepsButton } from '@18f/identity-form-steps';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import type { VerifyFlowValues } from '../../verify-flow';

interface PasswordConfirmStepStepProps extends FormStepComponentProps<VerifyFlowValues> {}

function PasswordConfirmStep({ registerField, onChange }: PasswordConfirmStepStepProps) {
  return (
    <>
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
