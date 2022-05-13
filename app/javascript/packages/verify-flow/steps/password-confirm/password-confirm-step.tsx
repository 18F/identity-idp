import type { ChangeEvent } from 'react';
import { useContext } from 'react';
import { t } from '@18f/identity-i18n';
import { Button } from '@18f/identity-components';
import { FormStepsButton, useHistoryParam } from '@18f/identity-form-steps';
import { PasswordToggle } from '@18f/identity-password-toggle';
import { Alert } from '@18f/identity-components';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import { ForgotPassword } from './forgot-password';
import { VerifyFlowContext } from '@18f//identity-verify-flow';
import { formatHTML } from '@18f/identity-react-i18n';
import type { VerifyFlowValues } from '../../verify-flow';

interface PasswordConfirmStepStepProps extends FormStepComponentProps<VerifyFlowValues> {}

function PasswordConfirmStep({ errors, registerField, onChange }: PasswordConfirmStepStepProps) {
  const { basePath } = useContext(VerifyFlowContext);
  const stepPath = `${basePath}/password_confirm`;
  const [path, setPath] = useHistoryParam(undefined, { basePath: stepPath });

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

      {formatHTML(
        t('idv.forgot_password.link_html', {
          link: `<button>${t('idv.forgot_password.link_text')}</button>`,
        }),
        {
          button: ({ children }) => (
            <Button isUnstyled onClick={() => goToForgotPassword()}>
              {children}
            </Button>
          ),
        },
      )}

      <FormStepsButton.Continue />
    </>
  );
}

export default PasswordConfirmStep;
