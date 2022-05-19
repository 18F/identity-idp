import { useContext } from 'react';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import { t } from '@18f/identity-i18n';
import { FormStepsButton, useHistoryParam, FormStepsContext } from '@18f/identity-form-steps';
import { PasswordToggle } from '@18f/identity-password-toggle';
import { FlowContext } from '@18f/identity-verify-flow';
import { formatHTML } from '@18f/identity-react-i18n';
import { PageHeading, Accordion, Alert, Button, Link } from '@18f/identity-components';
import { getConfigValue } from '@18f/identity-config';
import type { ChangeEvent } from 'react';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import { ForgotPassword } from './forgot-password';
import PersonalInfoSummary from './personal-info-summary';
import StartOverOrCancel from '../../start-over-or-cancel';
import type { VerifyFlowValues } from '../..';

interface PasswordConfirmStepProps extends FormStepComponentProps<VerifyFlowValues> {}

function PasswordConfirmStep({ errors, registerField, onChange, value }: PasswordConfirmStepProps) {
  const { basePath } = useContext(FlowContext);
  const { onPageTransition } = useContext(FormStepsContext);
  const stepPath = `${basePath}/password_confirm`;
  const [path, setPath] = useHistoryParam(undefined, { basePath: stepPath });
  useDidUpdateEffect(onPageTransition, [path]);

  function goToForgotPassword() {
    setPath('forgot_password');
  }

  function goBack() {
    setPath(undefined);
  }

  if (path === 'forgot_password') {
    return <ForgotPassword goBack={goBack} />;
  }

  const appName = getConfigValue('appName');

  return (
    <>
      {errors.map(({ error }) => (
        <Alert key={error.message} type="error" className="margin-bottom-4">
          {error.message}
        </Alert>
      ))}
      <PageHeading>{t('idv.titles.session.review', { app_name: appName })}</PageHeading>
      <p>{t('idv.messages.sessions.review_message', { app_name: appName })}</p>
      <p>
        <Link href="https://login.gov/security/">
          {t('idv.messages.sessions.read_more_encrypt', { app_name: appName })}
        </Link>
      </p>
      <PasswordToggle
        ref={registerField('password')}
        type="password"
        onInput={(event: ChangeEvent<HTMLInputElement>) => {
          onChange({ password: event.target.value });
        }}
        className="margin-top-6"
      />
      <div className="text-right margin-top-2 margin-bottom-4">
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
      </div>
      <Accordion header={t('idv.messages.review.intro')}>
        <PersonalInfoSummary pii={value} />
      </Accordion>
      <FormStepsButton.Continue />
      <StartOverOrCancel />
    </>
  );
}

export default PasswordConfirmStep;
