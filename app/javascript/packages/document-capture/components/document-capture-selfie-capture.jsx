import { t } from '@18f/identity-i18n';
import DocumentSideAcuantCapture from './document-side-acuant-capture';
import TipList from './tip-list';

/** @typedef {import('@18f/identity-form-steps').FormStepError<*>} FormStepError */
/** @typedef {import('@18f/identity-form-steps').RegisterFieldCallback} RegisterFieldCallback */
/** @typedef {import('@18f/identity-form-steps').OnErrorCallback} OnErrorCallback */

/**
 * @typedef DocumentCaptureSelfieCaptureProps
 *
 * @prop {RegisterFieldCallback} registerField
 * @prop {Blob|string|null|undefined} value
 * @prop {(nextValues:{[key:string]: Blob|string|null|undefined})=>void} onChange Update values,
 * merging with existing values.
 * @prop {FormStepError[]} errors
 * @prop {OnErrorCallback} onError
 * @prop {string=} className
 */

/**
 * @param {DocumentCaptureSelfieCaptureProps} props Props object.
 */
function DocumentCaptureSelfieCapture({
  registerField,
  value,
  onChange,
  errors,
  onError,
  className,
}) {
  return (
    <>
      <h2>2. {t('doc_auth.headings.document_capture_subheader_selfie')}</h2>
      <TipList
        titleClassName="margin-bottom-0 text-bold"
        title={t('doc_auth.tips.document_capture_selfie_selfie_text')}
        items={[
          t('doc_auth.tips.document_capture_selfie_text1'),
          t('doc_auth.tips.document_capture_selfie_text2'),
          t('doc_auth.tips.document_capture_selfie_text3'),
        ]}
      />
      <DocumentSideAcuantCapture
        key="selfie"
        side="selfie"
        registerField={registerField}
        value={value}
        onChange={onChange}
        errors={errors}
        onError={onError}
        className={className}
      />
    </>
  );
}

export default DocumentCaptureSelfieCapture;
