import type { ChangeEvent } from 'react';
import { useContext } from 'react';
import { t } from '@18f/identity-i18n';
import { Button } from '@18f/identity-components';
import { FormStepsButton, useHistoryParam } from '@18f/identity-form-steps';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import { ForgotPassword } from './forgot-password';
import { VerifyFlowContext } from '@18f//identity-verify-flow';
import type { VerifyFlowValues } from '../../verify-flow';

interface PasswordConfirmStepStepProps extends FormStepComponentProps<VerifyFlowValues> {}

function PasswordConfirmStep({ registerField, onChange }: PasswordConfirmStepStepProps) {
  const { basePath } = useContext(VerifyFlowContext);
  const [path, setPath] = useHistoryParam(basePath);

  function goToForgotPassword() {
    setPath('forgot_password');
  }

  function goBack() {
    setPath('password_confirm');
  }

  if (path === 'forgot_password') {
    return <ForgotPassword goBack={goBack} />;
  }

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
      <Button
        isUnstyled
        onClick={() => {
          goToForgotPassword();
        }}
      >
        Forgot password?
      </Button>
      <FormStepsButton.Continue />
    </>
  );
}

export default PasswordConfirmStep;
