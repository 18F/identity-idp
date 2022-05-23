import { useContext } from 'react';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import { t } from '@18f/identity-i18n';
import {
  FormStepsButton,
  useHistoryParam,
  FormStepsContext,
  HistoryLink,
} from '@18f/identity-form-steps';
import { PasswordToggle } from '@18f/identity-password-toggle';
import { FlowContext } from '@18f/identity-verify-flow';
import { formatHTML } from '@18f/identity-react-i18n';
import { PageHeading, Accordion, Alert, Link } from '@18f/identity-components';
import { getConfigValue } from '@18f/identity-config';
import type { ChangeEvent } from 'react';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import { ForgotPassword } from './forgot-password';
import PersonalInfoSummary from './personal-info-summary';
import StartOverOrCancel from '../../start-over-or-cancel';
import type { VerifyFlowValues } from '../..';

interface PasswordConfirmStepProps extends FormStepComponentProps<VerifyFlowValues> {}

const FORGOT_PASSWORD_PATH = 'forgot_password';

function PasswordConfirmStep({ errors, registerField, onChange, value }: PasswordConfirmStepProps) {
  const { basePath } = useContext(FlowContext);
  const { onPageTransition } = useContext(FormStepsContext);
  const stepPath = `${basePath}/password_confirm`;
  const [path] = useHistoryParam(undefined, { basePath: stepPath });
  useDidUpdateEffect(onPageTransition, [path]);

  if (path === FORGOT_PASSWORD_PATH) {
    return <ForgotPassword stepPath={stepPath} />;
  }

  const appName = getConfigValue('appName');

  return (
    <>
      {value.phone && !errors.length && (
        <Alert type="success" className="margin-bottom-4">
          {formatHTML(
            t('idv.messages.review.info_verified_html', {
              phone_message: `<strong>${t('idv.messages.phone.phone_of_record')}</strong>`,
            }),
            { strong: 'strong' },
          )}
        </Alert>
      )}
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
              <HistoryLink basePath={stepPath} step={FORGOT_PASSWORD_PATH}>
                {children}
              </HistoryLink>
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
