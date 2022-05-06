import type { ChangeEvent } from 'react';
import { t } from '@18f/identity-i18n';
import { FormStepsButton, useHistoryParam } from '@18f/identity-form-steps';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import type { VerifyFlowValues } from '../../verify-flow';

interface PasswordConfirmStepStepProps extends FormStepComponentProps<VerifyFlowValues> {}

function PasswordConfirmStep({ registerField, onChange }: PasswordConfirmStepStepProps) {
  const [path, setPath] = useHistoryParam(undefined, { basePath: '/verify/v2/password_confirm' });

  function goToForgotPassword() {
    console.log('path', path);
    setPath('forgot_password');
  }

  function goBack() {
    setPath('password_confirm');
  }

  if (path === 'forgot_password') {
    return <ForgotPassword goBack={goBack}></ForgotPassword>;
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
