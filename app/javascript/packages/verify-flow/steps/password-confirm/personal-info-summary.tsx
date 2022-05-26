import { parse, format } from 'libphonenumber-js';
import { t } from '@18f/identity-i18n';
import type { VerifyFlowValues } from '../../verify-flow';

interface PersonalInfoSummaryProps {
  pii: VerifyFlowValues;
}

function PersonalInfoSummary({ pii }: PersonalInfoSummaryProps) {
  const { firstName, lastName, dob, address1, address2, city, state, zipcode, ssn, phone } = pii;
  const phoneNumber = parse(`+1${phone}`);
  const formatted = format(phoneNumber, 'NATIONAL');

  function getDateFormat(date: string) {
    return new Date(date).toLocaleDateString(document.documentElement.lang, {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      timeZone: 'UTC',
    });
  }

  return (
    <div className="padding-x-4">
      <div className="h6">{t('idv.review.full_name')}</div>
      <div className="h4 text-bold ico-absolute ico-absolute-success">
        {firstName} {lastName}
      </div>
      <div className="margin-top-4 h6">{t('idv.review.mailing_address')}</div>
      <div className="h4 text-bold ico-absolute ico-absolute-success">
        {address1}
        <br />
        {address2 && (
          <>
            {address2}
            <br />
          </>
        )}
        {city && state ? `${city}, ${state} ${zipcode}` : ''}
      </div>
      {dob && (
        <>
          <div className="margin-top-4 h6">{t('idv.review.dob')}</div>
          <div className="h4 text-bold ico-absolute ico-absolute-success">{getDateFormat(dob)}</div>
        </>
      )}
      <div className="margin-top-4 h6">{t('idv.review.ssn')}</div>
      <div className="h4 text-bold ico-absolute ico-absolute-success">{ssn}</div>
      {phone && (
        <>
          <div className="h6 margin-top-4"> {t('idv.messages.phone.phone_of_record')}</div>
          <div className="h4 text-bold ico-absolute ico-absolute-success">{formatted}</div>
        </>
      )}
    </div>
  );
}

export default PersonalInfoSummary;
