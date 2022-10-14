import { useContext, useEffect, useState } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import { FormStepsContext, FormStepsButton } from '@18f/identity-form-steps';
import { PageHeading } from '@18f/identity-components';
import { Cancel } from '@18f/identity-verify-flow';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import DeviceContext from '../context/device';
import DocumentSideAcuantCapture from './document-side-acuant-capture';
import ServiceProviderContext from '../context/service-provider';
import withBackgroundEncryptedUpload from '../higher-order/with-background-encrypted-upload';
import type { PII } from '../services/upload';
import DocumentCaptureTroubleshootingOptions from './document-capture-troubleshooting-options';
import Warning from './warning';
import AnalyticsContext from '../context/analytics';
import BarcodeAttentionWarning from './barcode-attention-warning';
import FailedCaptureAttemptsContext from '../context/failed-capture-attempts';

type DocumentSide = 'front' | 'back';

interface ReviewIssuesStepValue {
  /**
   * Front image value.
   */
  front: Blob | string | null | undefined;

  /**
   * Back image value.
   */
  back: Blob | string | null | undefined;

  /**
   * Front image metadata.
   */
  front_image_metadata?: string;

  /**
   * Back image metadata.
   */
  back_image_metadata?: string;
}

interface ReviewIssuesStepProps extends FormStepComponentProps<ReviewIssuesStepValue> {
  remainingAttempts: number;

  isFailedResult: boolean;

  captureHints: boolean;

  pii?: PII;
}

/**
 * Sides of document to present as file input.
 */
const DOCUMENT_SIDES: DocumentSide[] = ['front', 'back'];

const DISPLAY_ATTEMPTS = 3;

function ReviewIssuesStep({
  value = {},
  onChange = () => {},
  errors = [],
  unknownFieldErrors = [],
  onError = () => {},
  registerField = () => undefined,
  remainingAttempts = Infinity,
  isFailedResult = false,
  pii,
  captureHints = false,
}: ReviewIssuesStepProps) {
  const { t } = useI18n();
  const { trackEvent } = useContext(AnalyticsContext);
  const [hasDismissed, setHasDismissed] = useState(remainingAttempts === Infinity);
  const { onPageTransition, changeStepCanComplete } = useContext(FormStepsContext);
  useDidUpdateEffect(onPageTransition, [hasDismissed]);

  const { onFailedSubmissionAttempt } = useContext(FailedCaptureAttemptsContext);
  useEffect(() => onFailedSubmissionAttempt(), []);
  function onWarningPageDismissed() {
    trackEvent('IdV: Capture troubleshooting dismissed');

    setHasDismissed(true);
  }

  // let FormSteps know, via FormStepsContext, whether this page
  // is ready to submit form values
  useEffect(() => {
    changeStepCanComplete(!!hasDismissed);
  }, [hasDismissed]);

  if (!hasDismissed) {
    if (pii) {
      return <BarcodeAttentionWarning onDismiss={onWarningPageDismissed} pii={pii} />;
    }

    return (
      <Warning
        heading={t('errors.doc_auth.throttled_heading')}
        actionText={t('idv.failure.button.warning')}
        actionOnClick={onWarningPageDismissed}
        location="doc_auth_review_issues"
        remainingAttempts={remainingAttempts}
        troubleshootingOptions={
          <DocumentCaptureTroubleshootingOptions
            location="post_submission_warning"
            hasErrors={!!errors?.length}
            showInPersonOption={!isFailedResult}
          />
        }
      >
        {!!unknownFieldErrors &&
          unknownFieldErrors
            .filter((error) => !['front', 'back'].includes(error.field!))
            .map(({ error }) => <p key={error.message}>{error.message}</p>)}

        {remainingAttempts <= DISPLAY_ATTEMPTS && (
          <p>
            <strong>
              {remainingAttempts === 1
                ? t('idv.failure.attempts.one')
                : t('idv.failure.attempts.other', { count: remainingAttempts })}
            </strong>
          </p>
        )}
      </Warning>
    );
  }

  return (
    <>
      <PageHeading>{t('doc_auth.headings.review_issues')}</PageHeading>
      {!!unknownFieldErrors &&
        unknownFieldErrors.map(({ error }) => <p key={error.message}>{error.message}</p>)}
      {captureHints && (
        <>
          <p className="margin-bottom-0">{t('doc_auth.tips.review_issues_id_header_text')}</p>
          <ul>
            <li>{t('doc_auth.tips.review_issues_id_text1')}</li>
            <li>{t('doc_auth.tips.review_issues_id_text2')}</li>
            <li>{t('doc_auth.tips.review_issues_id_text3')}</li>
            <li>{t('doc_auth.tips.review_issues_id_text4')}</li>
          </ul>
        </>
      )}
      {DOCUMENT_SIDES.map((side) => (
        <DocumentSideAcuantCapture
          key={side}
          side={side}
          registerField={registerField}
          value={value[side]}
          onChange={onChange}
          errors={errors}
          onError={onError}
          className="document-capture-review-issues-step__input"
        />
      ))}

      <FormStepsButton.Submit />
      <DocumentCaptureTroubleshootingOptions />
      <Cancel />
    </>
  );
}

export default withBackgroundEncryptedUpload(ReviewIssuesStep);
