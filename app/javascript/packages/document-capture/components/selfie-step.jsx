import { useContext } from 'react';
import { hasMediaAccess } from '@18f/identity-device';
import { useI18n } from '@18f/identity-react-i18n';
import { FormStepsContinueButton } from '@18f/identity-form-steps';
import DeviceContext from '../context/device';
import AcuantCapture from './acuant-capture';
import SelfieCapture from './selfie-capture';
import withBackgroundEncryptedUpload from '../higher-order/with-background-encrypted-upload';
import PageHeading from './page-heading';
import StartOverOrCancel from './start-over-or-cancel';

/**
 * @typedef SelfieStepValue
 *
 * @prop {Blob|string|null|undefined} selfie Selfie value.
 */

/**
 * @param {import('@18f/identity-form-steps').FormStepComponentProps<SelfieStepValue>} props Props object.
 */
function SelfieStep({
  value = {},
  onChange = () => {},
  errors = [],
  registerField = () => undefined,
}) {
  const { t } = useI18n();
  const { isMobile } = useContext(DeviceContext);
  const error = errors.find(({ field }) => field === 'selfie')?.error;

  return (
    <>
      <PageHeading>{t('doc_auth.headings.selfie')}</PageHeading>
      <p>{t('doc_auth.instructions.document_capture_selfie_instructions')}</p>
      <p className="margin-bottom-0">{t('doc_auth.tips.document_capture_header_text')}</p>
      <ul>
        <li>{t('doc_auth.tips.document_capture_selfie_text1')}</li>
        <li>{t('doc_auth.tips.document_capture_selfie_text2')}</li>
        <li>{t('doc_auth.tips.document_capture_selfie_text3')}</li>
      </ul>
      {isMobile || !hasMediaAccess() ? (
        <AcuantCapture
          ref={registerField('selfie', { isRequired: true })}
          capture="user"
          label={t('doc_auth.headings.document_capture_selfie')}
          bannerText={t('doc_auth.headings.photo')}
          value={value.selfie}
          onChange={(nextSelfie) => onChange({ selfie: nextSelfie })}
          allowUpload={false}
          errorMessage={error?.message}
          name="selfie"
        />
      ) : (
        <SelfieCapture
          ref={registerField('selfie', { isRequired: true })}
          value={value.selfie}
          onChange={(nextSelfie) => onChange({ selfie: nextSelfie })}
          errorMessage={error?.message}
        />
      )}
      <FormStepsContinueButton />
      <StartOverOrCancel />
    </>
  );
}

export default withBackgroundEncryptedUpload(SelfieStep);
