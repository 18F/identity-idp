import { PageHeading, Accordion } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import { FormStepsButton } from '@18f/identity-form-steps';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import parsePhoneNumber from 'libphonenumber-js';
import type { ChangeEvent } from 'react';
import type { VerifyFlowValues } from '../..';

interface PasswordConfirmStepProps extends FormStepComponentProps<VerifyFlowValues> {}

function getDateFormat(date) {
  date = new Date(date);
  const options = { year: 'numeric', month: 'long', day: 'numeric' };
  return date.toLocaleDateString('en-US', options);
}

function PersonalInfoSummary({ pii }) {
  const { firstName, lastName, dob, address1, address2, city, state, zipcode, ssn, phone } = pii;
  const phoneNumber = parsePhoneNumber(`+1${phone}`);
  return (
    <div className="padding-x-4">
      <div className="h6">{t('idv.review.full_name')}</div>
      <div className="h4 text-bold ico-absolute ico-absolute-success">
        {firstName} {lastName}
      </div>
      <div className="margin-top-4 h6">{t('idv.review.mailing_address')}</div>
      <div className="h4 text-bold ico-absolute ico-absolute-success">
        {address1} <br />
        {address2 || ''}
        <br />
        {city && state ? `${city}, ${state} ${zipcode}` : ''}
      </div>
      <div className="margin-top-4 h6">{t('idv.review.dob')}</div>
      <div className="h4 text-bold ico-absolute ico-absolute-success">{getDateFormat(dob)}</div>
      <div className="margin-top-4 h6">{t('idv.review.ssn')}</div>
      <div className="h4 text-bold ico-absolute ico-absolute-success">{ssn}</div>
      {phone && (
        <>
          <div className="h6 margin-top-4"> {t('idv.messages.phone.phone_of_record')}</div>
          <div className="h4 text-bold ico-absolute ico-absolute-success">
            {phoneNumber?.formatNational()}
          </div>
        </>
      )}
    </div>
  );
}

function PasswordConfirmStep({ registerField, onChange, value }: PasswordConfirmStepProps) {
  return (
    <>
      <PageHeading>{t('idv.titles.session.review', { app_name: 'Login.gov' })}</PageHeading>
      <p>{t('idv.messages.sessions.review_message', { app_name: 'Login.gov' })}</p>
      <div className="margin-bottom-4">
        <input
          ref={registerField('password')}
          aria-label={t('idv.form.password')}
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
    </>
  );
}

export default PasswordConfirmStep;
