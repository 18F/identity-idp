import React, { useContext } from 'react';
import { hasMediaAccess } from '@18f/identity-device';
import { RequiredValueMissingError } from './form-steps';
import useI18n from '../hooks/use-i18n';
import DeviceContext from '../context/device';
import AcuantCapture from './acuant-capture';
import SelfieCapture from './selfie-capture';
import FormErrorMessage from './form-error-message';

/**
 * @template V
 * @typedef {import('./form-steps').FormStepValidateResult<V>} FormStepValidateResult
 */

/**
 * @typedef SelfieStepValue
 *
 * @prop {Blob?=} selfie Selfie value.
 */

/**
 * @typedef SelfieStepProps
 *
 * @prop {SelfieStepValue=} value Current value.
 * @prop {(nextValue:Partial<SelfieStepValue>)=>void=} onChange Change handler.
 * @prop {Partial<FormStepValidateResult<SelfieStepValue>>=} errors Current validation errors.
 */

/**
 * @param {SelfieStepProps} props Props object.
 */
function SelfieStep({ value = {}, onChange = () => {}, errors = {} }) {
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
          allowUpload={false}
          className="id-card-file-input"
          errorMessage={errors.selfie ? <FormErrorMessage error={errors.selfie} /> : undefined}
        />
      ) : (
        <SelfieCapture
          value={value.selfie}
          onChange={(nextSelfie) => onChange({ selfie: nextSelfie })}
          errorMessage={errors.selfie ? <FormErrorMessage error={errors.selfie} /> : undefined}
        />
      )}
    </>
  );
}

/**
 * @type {import('./form-steps').FormStepValidate<SelfieStepValue>}
 */
export function validate(values) {
  const errors = {};

  if (!values.selfie) {
    errors.selfie = new RequiredValueMissingError();
  }

  return errors;
}

export default SelfieStep;
