import { useContext } from 'react';
import { Alert, PageHeading } from '@18f/identity-components';
import { ClipboardButton } from '@18f/identity-clipboard-button';
import { PrintButton } from '@18f/identity-print-button';
import { t } from '@18f/identity-i18n';
import { formatHTML } from '@18f/identity-react-i18n';
import { FormStepsButton } from '@18f/identity-form-steps';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import { getAssetPath } from '@18f/identity-assets';
import { trackEvent } from '@18f/identity-analytics';
import type { VerifyFlowValues } from '../../verify-flow';
import AddressVerificationMethodContext from '../../context/address-verification-method-context';
import DownloadButton from './download-button';

interface PersonalKeyStepProps extends FormStepComponentProps<VerifyFlowValues> {}

function PersonalKeyStep({ value }: PersonalKeyStepProps) {
  const personalKey = value.personalKey!;
  const { addressVerificationMethod } = useContext(AddressVerificationMethodContext);

  return (
    <>
      {addressVerificationMethod && (
        <Alert type="success" className="margin-bottom-4">
          {addressVerificationMethod === 'phone' && t('idv.messages.confirm')}
          {addressVerificationMethod === 'gpo' && t('idv.messages.mail_sent')}
        </Alert>
      )}
      <PageHeading>{t('headings.personal_key')}</PageHeading>
      <p>{t('instructions.personal_key.info')}</p>
      <div className="full-width-box margin-y-5">
        <div className="border-y border-primary-light bg-primary-lightest padding-y-3 text-center">
          <h2 className="margin-y-0">{t('users.personal_key.header')}</h2>
          <div className="bg-personal-key padding-top-4 margin-y-2">
            <div className="padding-x-0 tablet:padding-x-1 padding-y-2 separator-text bg-pk-box">
              {personalKey.split('-').map((segment, index) => (
                <strong key={[segment, index].join()} className="separator-text__code">
                  {segment}
                </strong>
              ))}
            </div>
          </div>
          <p className="margin-y-0">
            {formatHTML(
              t('users.personal_key.generated_on_html', {
                date: `<strong>${new Intl.DateTimeFormat([], {
                  dateStyle: 'long',
                }).format()}</strong>`,
              }),
              { strong: 'strong' },
            )}
          </p>
        </div>
      </div>
      <DownloadButton
        content={personalKey}
        fileName="personal_key.txt"
        onClick={() => trackEvent('IdV: download personal key')}
        isOutline
        className="margin-right-2 margin-bottom-2 tablet:margin-bottom-0"
      >
        {t('forms.backup_code.download')}
      </DownloadButton>
      <PrintButton
        isOutline
        onClick={() => trackEvent('IdV: print personal key')}
        className="margin-right-2 margin-bottom-2 tablet:margin-bottom-0"
      />
      <ClipboardButton
        clipboardText={personalKey}
        isOutline
        onClick={() => trackEvent('IdV: copy personal key')}
        className="margin-bottom-2 tablet:margin-bottom-0"
      />
      <div className="margin-y-5 clearfix">
        <img
          className="float-left margin-right-2"
          alt=""
          src={getAssetPath('icon-lock-alert-important.svg')}
          width="80"
          height="80"
        />
        <p className="margin-bottom-0">
          <strong>{t('instructions.personal_key.email_title')}</strong>
        </p>
        <p>{t('instructions.personal_key.email_body')}</p>
      </div>
      <FormStepsButton.Continue className="margin-bottom-0" />
    </>
  );
}

export default PersonalKeyStep;
