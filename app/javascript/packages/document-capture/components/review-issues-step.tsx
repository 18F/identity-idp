import { useContext, useEffect, useState, ReactNode } from 'react';
import { useI18n, formatHTML } from '@18f/identity-react-i18n';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import { FormStepsContext, FormStepsButton } from '@18f/identity-form-steps';
import { PageHeading } from '@18f/identity-components';
import { Cancel } from '@18f/identity-verify-flow';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import DocumentSideAcuantCapture from './document-side-acuant-capture';
import type { PII } from '../services/upload';
import DocumentCaptureTroubleshootingOptions from './document-capture-troubleshooting-options';
import Warning from './warning';
import AnalyticsContext from '../context/analytics';
import BarcodeAttentionWarning from './barcode-attention-warning';
import FailedCaptureAttemptsContext from '../context/failed-capture-attempts';
import { InPersonContext } from '../context';
import UnknownError from './unknown-error';
import TipList from './tip-list';

function formatWithStrongNoWrap(text: string): ReactNode {
  return formatHTML(text, {
    strong: ({ children }) => <strong className="text-no-wrap">{children}</strong>,
  });
}

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
  remainingAttempts?: number;

  isFailedResult?: boolean;

  isFailedDocType?: boolean;

  captureHints?: boolean;

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
  isFailedDocType = false,
  pii,
  captureHints = false,
}: ReviewIssuesStepProps) {
  const { t } = useI18n();
  const { trackEvent } = useContext(AnalyticsContext);
  const [hasDismissed, setHasDismissed] = useState(remainingAttempts === Infinity);
  const { onPageTransition, changeStepCanComplete } = useContext(FormStepsContext);
  useDidUpdateEffect(onPageTransition, [hasDismissed]);

  const { onFailedSubmissionAttempt } = useContext(FailedCaptureAttemptsContext);
  const { inPersonURL } = useContext(InPersonContext);
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
    const heading = isFailedDocType
      ? t('errors.doc_auth.doc_type_not_supported_heading')
      : t('errors.doc_auth.rate_limited_heading');
    const actionText =
      !inPersonURL || isFailedResult
        ? t('idv.failure.button.warning')
        : t('idv.failure.button.try_online');
    const subHeading = (!inPersonURL || isFailedResult) && !isFailedDocType && (
      <h2>{t('errors.doc_auth.rate_limited_subheading')}</h2>
    );
    const showSPOptions = !(!inPersonURL || isFailedResult);
    const hasCancel = !inPersonURL || isFailedResult;
    // Warning(try again screen)
    return (
      <>
        <Warning
          heading={heading}
          actionText={actionText}
          actionOnClick={onWarningPageDismissed}
          location="doc_auth_review_issues"
          remainingAttempts={remainingAttempts}
          troubleshootingOptions={
            <DocumentCaptureTroubleshootingOptions
              location="post_submission_warning"
              showAlternativeProofingOptions={!isFailedResult}
              showSPOption={showSPOptions}
              heading={t('components.troubleshooting_options.ipp_heading')}
            />
          }
        >
          {!!subHeading && subHeading}
          <UnknownError
            unknownFieldErrors={unknownFieldErrors}
            remainingAttempts={remainingAttempts}
            isFailedDocType={isFailedDocType}
          />

          {!isFailedDocType && remainingAttempts <= DISPLAY_ATTEMPTS && (
            <p>
              {formatWithStrongNoWrap(t('idv.failure.attempts_html', { count: remainingAttempts }))}
            </p>
          )}
        </Warning>
        {hasCancel && <Cancel />}
      </>
    );
  }
  // hasDismissed = true
  return (
    <>
      <PageHeading>{t('doc_auth.headings.review_issues')}</PageHeading>
      <UnknownError
        unknownFieldErrors={unknownFieldErrors}
        remainingAttempts={remainingAttempts}
        isFailedDocType={isFailedDocType}
        altFailedDocTypeMsg={isFailedDocType ? t('doc_auth.errors.doc.wrong_id_type') : null}
      />

      {!isFailedDocType && captureHints && (
        <TipList
          title={t('doc_auth.tips.review_issues_id_header_text')}
          items={[
            t('doc_auth.tips.review_issues_id_text1'),
            t('doc_auth.tips.review_issues_id_text2'),
            t('doc_auth.tips.review_issues_id_text3'),
            t('doc_auth.tips.review_issues_id_text4'),
          ]}
          translationNeeded={false}
        />
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

export default ReviewIssuesStep;
