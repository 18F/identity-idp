import { PageHeading, Accordion, Alert } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import { FormStepsButton } from '@18f/identity-form-steps';
import { PasswordToggle } from '@18f/identity-password-toggle';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import type { ChangeEvent } from 'react';
import { getConfigValue } from '@18f/identity-config';
import PersonalInfoSummary from './personal-info-summary';
import StartOverOrCancel from '../../start-over-or-cancel';
import type { VerifyFlowValues } from '../..';

interface PasswordConfirmStepProps extends FormStepComponentProps<VerifyFlowValues> {}

function PasswordConfirmStep({ errors, registerField, onChange, value }: PasswordConfirmStepProps) {
  return (
    <>
      {errors.map(({ error }) => (
        <Alert key={error.message} type="error" className="margin-bottom-4">
          {error.message}
        </Alert>
      ))}
      return{' '}
      <PageHeading>
        {t('idv.titles.session.review', { app_name: getConfigValue('appName') })}
      </PageHeading>
      <div className="margin-top-6 margin-bottom-4">
        <PasswordToggle
          ref={registerField('password')}
          type="password"
          onInput={(event: ChangeEvent<HTMLInputElement>) => {
            onChange({ password: event.target.value });
          }}
        />
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
