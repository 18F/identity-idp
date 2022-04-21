import { t } from '@18f/identity-i18n';
import { FormError } from '@18f/identity-form-steps';
import AcuantCapture from './acuant-capture';

/** @typedef {import('@18f/identity-form-steps').FormStepError<*>} FormStepError */
/** @typedef {import('@18f/identity-form-steps').RegisterFieldCallback} RegisterFieldCallback */
/** @typedef {import('@18f/identity-form-steps').OnErrorCallback} OnErrorCallback */

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
 * An error representing user declined access to camera.
 */
export class CameraAccessDeclinedError extends FormError {
  get message() {
    return this.isDetail
      ? t('doc_auth.errors.camera.blocked_detail')
      : t('doc_auth.errors.camera.blocked');
  }
}

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
        onError(new CameraAccessDeclinedError({ isDetail: true }));
      }}
      errorMessage={error ? error.message : undefined}
      name={side}
      className={className}
      capture="environment"
    />
  );
}

export default DocumentSideAcuantCapture;
