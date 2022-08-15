import { useContext } from 'react';
import type { ChangeEvent } from 'react';
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
import { PageHeading, Accordion, Alert, Link, ScrollIntoView } from '@18f/identity-components';
import { getConfigValue } from '@18f/identity-config';
import { trackEvent } from '@18f/identity-analytics';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import { ForgotPassword } from './forgot-password';
import PersonalInfoSummary from './personal-info-summary';
import Cancel from '../../cancel';
import AddressVerificationMethodContext from '../../context/address-verification-method-context';
import type { VerifyFlowValues } from '../..';
import { PasswordSubmitError } from './submit';

interface PasswordConfirmStepProps extends FormStepComponentProps<VerifyFlowValues> {}

const FORGOT_PASSWORD_PATH = 'forgot_password';

function useSubpageEventLogger(path) {
  useDidUpdateEffect(() => {
    switch (path) {
      case 'forgot_password':
        trackEvent('IdV: forgot password visited');
        break;
      default:
        trackEvent('IdV: password confirm visited');
    }
  }, [path]);
}

function PasswordConfirmStep({ errors, registerField, onChange, value }: PasswordConfirmStepProps) {
  const { basePath } = useContext(FlowContext);
  const { onPageTransition } = useContext(FormStepsContext);
  const { addressVerificationMethod } = useContext(AddressVerificationMethodContext);
  const stepPath = `${basePath}/password_confirm`;
  const [path] = useHistoryParam(undefined, { basePath: stepPath });
  useDidUpdateEffect(onPageTransition, [path]);
  useSubpageEventLogger(path);

  if (path === FORGOT_PASSWORD_PATH) {
    return <ForgotPassword stepPath={stepPath} />;
  }

  const appName = getConfigValue('appName');
  const stepErrors = errors.filter(({ error }) => error instanceof PasswordSubmitError);

  return (
    <>
      {addressVerificationMethod === 'phone' && (
        <Alert type="success" className="margin-bottom-4">
          {formatHTML(
            t('idv.messages.review.info_verified_html', {
              phone_message: `<strong>${t('idv.messages.phone.phone_of_record')}</strong>`,
            }),
            { strong: 'strong' },
          )}
        </Alert>
      )}
      {stepErrors.length > 0 && (
        <ScrollIntoView>
          {stepErrors.map(({ error }) => (
            <Alert key={error.message} type="error" className="margin-bottom-4">
              {error.message}
            </Alert>
          ))}
        </ScrollIntoView>
      )}
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
        required
      />
      <div className="text-right margin-top-2 margin-bottom-4">
        {formatHTML(
          t('idv.forgot_password.link_html', {
            link: `<button>${t('idv.forgot_password.link_text')}</button>`,
          }),
          {
            button: ({ children }) => (
              <HistoryLink
                basePath={stepPath}
                step={FORGOT_PASSWORD_PATH}
                title={`${t('idv.forgot_password.link_html').replace(`%{link}`, '')} ${t(
                  'idv.forgot_password.link_text',
                )}`}
              >
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
      <Cancel />
    </>
  );
}

export default PasswordConfirmStep;
