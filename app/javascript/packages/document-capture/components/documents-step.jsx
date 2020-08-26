import React, { useContext } from 'react';
import AcuantCapture from './acuant-capture';
import FormErrorMessage from './form-error-message';
import { RequiredValueMissingError } from './form-steps';
import useI18n from '../hooks/use-i18n';
import DeviceContext from '../context/device';

/**
 * @template V
 * @typedef {import('./form-steps').FormStepValidateResult<V>} FormStepValidateResult
 */

/**
 * @typedef DocumentsStepValue
 *
 * @prop {Blob=} front Front image value.
 * @prop {Blob=} back Back image value.
 */

/**
 * @typedef DocumentsStepProps
 *
 * @prop {DocumentsStepValue=} value Current value.
 * @prop {(nextValue:Partial<DocumentsStepValue>)=>void=} onChange Value change handler.
 * @prop {Partial<FormStepValidateResult<DocumentsStepValue>>=} errors Current validation errors.
 */

/**
 * Sides of document to present as file input.
 *
 * @type {string[]}
 */
const DOCUMENT_SIDES = ['front', 'back'];

/**
 * @param {DocumentsStepProps} props Props object.
 */
function DocumentsStep({ value = {}, onChange = () => {}, errors = {} }) {
  const { t } = useI18n();
  const { isMobile } = useContext(DeviceContext);

  return (
    <>
      <p className="margin-bottom-0">{t('doc_auth.tips.document_capture_header_text')}</p>
      <ul>
        <li>{t('doc_auth.tips.document_capture_id_text1')}</li>
        <li>{t('doc_auth.tips.document_capture_id_text2')}</li>
        <li>{t('doc_auth.tips.document_capture_id_text3')}</li>
        {!isMobile && <li>{t('doc_auth.tips.document_capture_id_text4')}</li>}
      </ul>
      {DOCUMENT_SIDES.map((side) => (
        <AcuantCapture
          key={side}
          /* i18n-tasks-use t('doc_auth.headings.document_capture_back') */
          /* i18n-tasks-use t('doc_auth.headings.document_capture_front') */
          label={t(`doc_auth.headings.document_capture_${side}`)}
          /* i18n-tasks-use t('doc_auth.headings.back') */
          /* i18n-tasks-use t('doc_auth.headings.front') */
          bannerText={t(`doc_auth.headings.${side}`)}
          value={value[side]}
          onChange={(nextValue) => onChange({ [side]: nextValue })}
          className="id-card-file-input"
          errorMessage={errors[side] ? <FormErrorMessage error={errors[side]} /> : undefined}
        />
      ))}
    </>
  );
}

/**
 * @type {import('./form-steps').FormStepValidate<DocumentsStepValue>}
 */
export function validate(values) {
  const errors = {};

  if (!values.front) {
    errors.front = new RequiredValueMissingError();
  }

  if (!values.back) {
    errors.back = new RequiredValueMissingError();
  }

  return errors;
}

export default DocumentsStep;
