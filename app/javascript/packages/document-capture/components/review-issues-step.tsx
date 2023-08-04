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

const DISPLAY_ATTEMPTS = 100;

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

  function DocTypeErrorMessage({ error }) {
    return (
      <p key={error.message}>
        {error.message}{' '}
        {formatWithStrongNoWrap(t('idv.warning.attempts_html', { count: remainingAttempts }))}
      </p>
    );
  }
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
    // ipp disabled
    if (!inPersonURL || isFailedResult) {
      if (isFailedDocType) {
        return (
          <>
            <Warning
              heading={t('errors.doc_auth.doc_type_not_supported_heading')}
              actionText={t('idv.failure.button.warning')}
              actionOnClick={onWarningPageDismissed}
              location="doc_auth_review_issues"
              remainingAttempts={remainingAttempts}
              troubleshootingOptions={
                <DocumentCaptureTroubleshootingOptions
                  location="post_submission_warning"
                  showAlternativeProofingOptions={!isFailedResult}
                  showSPOption={false}
                  heading={t('components.troubleshooting_options.ipp_heading')}
                />
              }
            >
              {!!unknownFieldErrors &&
                unknownFieldErrors
                  .filter((error) => !['front', 'back'].includes(error.field!))
                  .map(({ error }) => <DocTypeErrorMessage key={error.message} error={error} />)}
            </Warning>
            <Cancel />
          </>
        );
      }
      return (
        <>
          <Warning
            heading={t('errors.doc_auth.rate_limited_heading')}
            actionText={t('idv.failure.button.warning')}
            actionOnClick={onWarningPageDismissed}
            location="doc_auth_review_issues"
            remainingAttempts={remainingAttempts}
            troubleshootingOptions={
              <DocumentCaptureTroubleshootingOptions
                location="post_submission_warning"
                showAlternativeProofingOptions={!isFailedResult}
                showSPOption={false}
                heading={t('components.troubleshooting_options.ipp_heading')}
              />
            }
          >
            {!!unknownFieldErrors &&
              unknownFieldErrors
                .filter((error) => !['front', 'back'].includes(error.field!))
                .map(({ error }) => <p key={error.message}>{error.message}</p>)}

            {remainingAttempts <= DISPLAY_ATTEMPTS && (
              <p>
                {formatWithStrongNoWrap(
                  t('idv.failure.attempts_html', { count: remainingAttempts }),
                )}
              </p>
            )}
          </Warning>
          <Cancel />
        </>
      );
    }
    // ipp enabled

    if (isFailedDocType) {
      return (
        <Warning
          heading={t('errors.doc_auth.doc_type_not_supported_heading')}
          actionText={t('idv.failure.button.try_online')}
          actionOnClick={onWarningPageDismissed}
          location="doc_auth_review_issues"
          remainingAttempts={remainingAttempts}
          troubleshootingOptions={
            <DocumentCaptureTroubleshootingOptions
              location="post_submission_warning"
              showAlternativeProofingOptions={!isFailedResult}
              heading={t('components.troubleshooting_options.ipp_heading')}
            />
          }
        >
          {!!unknownFieldErrors &&
            unknownFieldErrors
              .filter((error) => !['front', 'back'].includes(error.field!))
              .map(({ error }) => <DocTypeErrorMessage key={error.message} error={error} />)}
        </Warning>
      );
    }

    return (
      <Warning
        heading={t('errors.doc_auth.rate_limited_heading')}
        actionText={t('idv.failure.button.try_online')}
        actionOnClick={onWarningPageDismissed}
        location="doc_auth_review_issues"
        remainingAttempts={remainingAttempts}
        troubleshootingOptions={
          <DocumentCaptureTroubleshootingOptions
            location="post_submission_warning"
            showAlternativeProofingOptions={!isFailedResult}
            heading={t('components.troubleshooting_options.ipp_heading')}
          />
        }
      >
        <h2>{t('errors.doc_auth.rate_limited_subheading')}</h2>
        {!!unknownFieldErrors &&
          unknownFieldErrors
            .filter((error) => !['front', 'back'].includes(error.field!))
            .map(({ error }) => <p key={error.message}>{error.message}</p>)}

        {remainingAttempts <= DISPLAY_ATTEMPTS && (
          <p>
            {formatWithStrongNoWrap(t('idv.failure.attempts_html', { count: remainingAttempts }))}
          </p>
        )}
      </Warning>
    );
  }
  // hasDismissed = true
  if (isFailedDocType) {
    return (
      <>
        <PageHeading>{t('doc_auth.headings.review_issues')}</PageHeading>
        {!!unknownFieldErrors &&
          unknownFieldErrors
            .filter((error) => !['front', 'back'].includes(error.field!))
            .map(({ error }) => <DocTypeErrorMessage key={error.message} error={error} />)}
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

export default ReviewIssuesStep;
