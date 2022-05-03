import { PageHeading } from '@18f/identity-components';
import { ClipboardButton } from '@18f/identity-clipboard-button';
import { PrintButton } from '@18f/identity-print-button';
import { t } from '@18f/identity-i18n';
import { formatHTML } from '@18f/identity-react-i18n';
import { FormStepsButton } from '@18f/identity-form-steps';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import { getAssetPath } from '@18f/identity-assets';
import type { VerifyFlowValues } from '../..';
import { Accordion } from '@18f/identity-components';
import parsePhoneNumber from 'libphonenumber-js';

interface PasswordConfirmStepProps extends FormStepComponentProps<VerifyFlowValues> {}

function get_date_format(date: string | number | Date) {
  date = new Date(date);
  const options = { year: 'numeric', month: 'long', day: 'numeric' };
  return date.toLocaleDateString('en-US', options);
}

function pii_summary(pii) {
  const phoneNumber = parsePhoneNumber(`+1${pii?.phone}`);

  return (
    <div className="padding-x-4">
      <div className="h6">{t('idv.review.full_name')}</div>
      <div className="h4 text-bold ico-absolute ico-absolute-success">
        {pii?.firstName} {pii?.lastName}
      </div>
      <div className="margin-top-4 h6">{t('idv.review.mailing_address')}</div>
      <div className="h4 text-bold ico-absolute ico-absolute-success">
        {pii?.address1} <br />
        {pii?.address2 ? pii?.address2 : ''}
        <br />
        {pii?.city && pii?.state ? `${pii?.city}, ${pii?.state} ${pii?.zipcode}` : ''}
      </div>
      <div className="margin-top-4 h6">{t('idv.review.dob')}</div>
      <div className="h4 text-bold ico-absolute ico-absolute-success">
        {get_date_format(pii?.dob)}
      </div>
      <div className="margin-top-4 h6">{t('idv.review.ssn')}</div>
      <div className="h4 text-bold ico-absolute ico-absolute-success">{pii?.ssn}</div>
      {pii?.phone ? (
        <>
          <div className="h6 margin-top-4"> {t('idv.messages.phone.phone_of_record')}</div>
          <div className="h4 text-bold ico-absolute ico-absolute-success">
            {phoneNumber?.formatNational()}
          </div>
        </>
      ) : (
        ''
      )}
    </div>
  );
}

function PasswordConfirmStep({ value }: PasswordConfirmStepProps) {
  return (
    <>
      <PageHeading>{t('idv.titles.session.review', { app_name: 'Login.gov' })}</PageHeading>
      <p>{t('idv.messages.sessions.review_message', { app_name: 'Login.gov' })}</p>
      <Accordion header={t('idv.messages.review.intro')}>{pii_summary(value)}</Accordion>
      <FormStepsButton.Continue className="margin-bottom-0" />
    </>
  );
}

export default PasswordConfirmStep;
