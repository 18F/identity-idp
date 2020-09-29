import React, { useContext } from 'react';
import { hasMediaAccess } from '@18f/identity-device';
import useI18n from '../hooks/use-i18n';
import DeviceContext from '../context/device';
import AcuantCapture from './acuant-capture';
import SelfieCapture from './selfie-capture';
import FormErrorMessage from './form-error-message';

/**
 * @typedef SelfieStepValue
 *
 * @prop {Blob?=} selfie Selfie value.
 */

/**
 * @param {import('./form-steps').FormStepComponentProps<SelfieStepValue>} props Props object.
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
          className="id-card-file-input"
          errorMessage={error ? <FormErrorMessage error={error} /> : undefined}
        />
      ) : (
        <SelfieCapture
          ref={registerField('selfie', { isRequired: true })}
          value={value.selfie}
          onChange={(nextSelfie) => onChange({ selfie: nextSelfie })}
          errorMessage={error ? <FormErrorMessage error={error} /> : undefined}
        />
      )}
    </>
  );
}

export default SelfieStep;
