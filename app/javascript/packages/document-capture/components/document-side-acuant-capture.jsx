import { useI18n } from '@18f/identity-react-i18n';
import AcuantCapture from './acuant-capture';
import FormErrorMessage, { CameraAccessDeclinedError } from './form-error-message';

/** @typedef {import('./form-steps').FormStepError<*>} FormStepError */
/** @typedef {import('./form-steps').RegisterFieldCallback} RegisterFieldCallback */
/** @typedef {import('./form-steps').OnErrorCallback} OnErrorCallback */

/**
 * @typedef DocumentSideAcuantCaptureProps
 *
 * @prop {'front'|'back'} side
 * @prop {RegisterFieldCallback} registerField
 * @prop {Blob|string|null|undefined} value
 * @prop {(nextValues:{[key:string]: Blob|string|null|undefined})=>void} onChange Update values,
 * merging with existing values.
 * @prop {FormStepError[]} errors
 * @prop {OnErrorCallback} onError
 * @prop {string=} className
 */

/**
 * @param {DocumentSideAcuantCaptureProps} props Props object.
 */
function DocumentSideAcuantCapture({
  side,
  registerField,
  value,
  onChange,
  errors,
  onError,
  className,
}) {
  const { t } = useI18n();
  const error = errors.find(({ field }) => field === side)?.error;

  return (
    <AcuantCapture
      ref={registerField(side, { isRequired: true })}
      /* i18n-tasks-use t('doc_auth.headings.document_capture_back') */
      /* i18n-tasks-use t('doc_auth.headings.document_capture_front') */
      label={t(`doc_auth.headings.document_capture_${side}`)}
      /* i18n-tasks-use t('doc_auth.headings.back') */
      /* i18n-tasks-use t('doc_auth.headings.front') */
      bannerText={t(`doc_auth.headings.${side}`)}
      value={value}
      onChange={(nextValue, metadata) =>
        onChange({
          [side]: nextValue,
          [`${side}_image_metadata`]: JSON.stringify(metadata),
        })
      }
      onCameraAccessDeclined={() => {
        onError(new CameraAccessDeclinedError(), { field: side });
        onError(new CameraAccessDeclinedError());
      }}
      errorMessage={error ? <FormErrorMessage error={error} /> : undefined}
      name={side}
      className={className}
      capture="environment"
    />
  );
}

export default DocumentSideAcuantCapture;
