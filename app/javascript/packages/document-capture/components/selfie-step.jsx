import React, { useContext } from 'react';
import { hasMediaAccess } from '@18f/identity-device';
import useI18n from '../hooks/use-i18n';
import DeviceContext from '../context/device';
import AcuantCapture from './acuant-capture';
import SelfieCapture from './selfie-capture';

/**
 * @typedef SelfieStepValue
 *
 * @prop {Blob?=} selfie Selfie value.
 */

/**
 * @typedef SelfieStepProps
 *
 * @prop {SelfieStepValue=}                            value    Current value.
 * @prop {(nextValue:Partial<SelfieStepValue>)=>void=} onChange Change handler.
 */

/**
 * @param {SelfieStepProps} props Props object.
 */
function SelfieStep({ value = {}, onChange = () => {} }) {
  const { t } = useI18n();
  const { isMobile } = useContext(DeviceContext);

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
          capture="user"
          label={t('doc_auth.headings.document_capture_selfie')}
          bannerText={t('doc_auth.headings.photo')}
          value={value.selfie}
          onChange={(nextSelfie) => onChange({ selfie: nextSelfie })}
          required
        />
      ) : (
        <SelfieCapture
          value={value.selfie}
          onChange={(nextSelfie) => onChange({ selfie: nextSelfie })}
        />
      )}
    </>
  );
}

/**
 * Returns true if the step is valid for the given values, or false otherwise.
 *
 * @param {Record<string,string>} value Current form values.
 *
 * @return {boolean} Whether step is valid.
 */
export const isValid = (value) => Boolean(value.selfie);

export default SelfieStep;
