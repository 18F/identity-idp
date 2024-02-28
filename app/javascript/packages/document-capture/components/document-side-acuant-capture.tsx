import { useContext } from 'react';
import { t } from '@18f/identity-i18n';
import { FormError, FormStepsContext } from '@18f/identity-form-steps';
import type {
  FormStepError,
  OnErrorCallback,
  RegisterFieldCallback,
} from '@18f/identity-form-steps';
import AcuantCapture from './acuant-capture';

interface DocumentSideAcuantCaptureProps {
  side: 'front' | 'back' | 'selfie';
  registerField: RegisterFieldCallback;
  value: Blob | string | null | undefined;
  /**
   * Update values, merging with existing values.
   */
  onChange: (nextValues: { [key: string]: Blob | string | null | undefined }) => void;
  errors: FormStepError<{ front: string; back: string; selfie: string }>[];
  onError: OnErrorCallback;
  className?: string;
}

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

function DocumentSideAcuantCapture({
  side,
  registerField,
  value,
  onChange,
  errors,
  onError,
  className,
}: DocumentSideAcuantCaptureProps) {
  const error = errors.find(({ field }) => field === side)?.error;
  const { changeStepCanComplete } = useContext(FormStepsContext);
  return (
    <AcuantCapture
      ref={registerField(side, { isRequired: true })}
      /* i18n-tasks-use t('doc_auth.headings.document_capture_back') */
      /* i18n-tasks-use t('doc_auth.headings.document_capture_front') */
      /* i18n-tasks-use t('doc_auth.headings.document_capture_selfie') */
      label={t(`doc_auth.headings.document_capture_${side}`)}
      /* i18n-tasks-use t('doc_auth.headings.back') */
      /* i18n-tasks-use t('doc_auth.headings.front') */
      /* i18n-tasks-use t('doc_auth.headings.selfie') */
      bannerText={t(`doc_auth.headings.${side}`)}
      value={value}
      onChange={(nextValue, metadata) => {
        onChange({
          [side]: nextValue,
          [`${side}_image_metadata`]: JSON.stringify(metadata),
        });
        if (metadata?.failedImageResubmission) {
          onError(new Error(t('doc_auth.errors.doc.resubmit_failed_image')), { field: side });
          changeStepCanComplete(false);
        } else {
          changeStepCanComplete(true);
        }
      }}
      onCameraAccessDeclined={() => {
        onError(new CameraAccessDeclinedError(), { field: side });
        onError(new CameraAccessDeclinedError(undefined, { isDetail: true }));
      }}
      errorMessage={error ? error.message : undefined}
      name={side}
      className={className}
    />
  );
}

export default DocumentSideAcuantCapture;
