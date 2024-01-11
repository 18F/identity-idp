import { Cancel } from '@18f/identity-verify-flow';
import { useI18n, HtmlTextWithStrongNoWrap } from '@18f/identity-react-i18n';
import { useContext, useEffect, useRef } from 'react';
import { FormStepError } from '@18f/identity-form-steps';
import Warning from './warning';
import DocumentCaptureTroubleshootingOptions from './document-capture-troubleshooting-options';
import UnknownError from './unknown-error';
import { InPersonContext } from '../context';
import AnalyticsContext from '../context/analytics';

interface DocumentCaptureWarningProps {
  isFailedDocType: boolean;
  isFailedResult: boolean;
  selfieResultFailed: boolean;
  selfieResultNotLiveOrPoorQuality: boolean;
  remainingAttempts: number;
  actionOnClick?: () => void;
  unknownFieldErrors: FormStepError<{ front: string; back: string }>[];
  hasDismissed: boolean;
}

const DISPLAY_ATTEMPTS = 3;

function getHeadingString({ isFailedDocType, selfieHasError, t }) {
  if (selfieHasError && !isFailedDocType) {
    return t('errors.doc_auth.selfie_result_failed_heading');
  }
  if (isFailedDocType) {
    return t('errors.doc_auth.doc_type_not_supported_heading');
  }
  return t('errors.doc_auth.rate_limited_heading');
}

function getActionTextString({ nonIppOrFailedResult, t }) {
  return nonIppOrFailedResult
    ? t('idv.failure.button.warning')
    : t('idv.failure.button.try_online');
}

function getSubheading({ selfieHasError, nonIppOrFailedResult, isFailedDocType, t }) {
  if (!nonIppOrFailedResult && !isFailedDocType && !selfieHasError) {
    return <h2>{t('errors.doc_auth.rate_limited_subheading')}</h2>;
  }
  return undefined;
}

function showRemainingAttemptsComponent({ isFailedDocType, remainingAttempts }) {
  if (isFailedDocType) {
    return false;
  }
  return remainingAttempts <= DISPLAY_ATTEMPTS;
}

function DocumentCaptureWarning({
  isFailedDocType,
  isFailedResult,
  selfieResultFailed,
  selfieResultNotLiveOrPoorQuality,
  remainingAttempts,
  actionOnClick,
  unknownFieldErrors = [],
  hasDismissed,
}: DocumentCaptureWarningProps) {
  const { t } = useI18n();
  const { inPersonURL } = useContext(InPersonContext);
  const { trackEvent } = useContext(AnalyticsContext);

  const nonIppOrFailedResult = !inPersonURL || isFailedResult;
  const selfieHasError = selfieResultFailed || selfieResultNotLiveOrPoorQuality;
  const heading = getHeadingString({ isFailedDocType, selfieHasError, t });
  const actionText = getActionTextString({ nonIppOrFailedResult, t });
  // we have an h2 subheading when nonIpp is false and isFailed is false
  const subheading = getSubheading({
    selfieHasError,
    nonIppOrFailedResult,
    isFailedDocType,
    t,
  });
  const subheadingRef = useRef<HTMLDivElement>(null);
  const errorMessageDisplayedRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const subheadingText = subheadingRef.current?.textContent;
    const errorMessageDisplayed = errorMessageDisplayedRef.current?.textContent;

    trackEvent('IdV: warning shown', {
      location: 'doc_auth_review_issues',
      remaining_attempts: remainingAttempts,
      heading,
      subheading: subheadingText,
      error_message_displayed: errorMessageDisplayed,
    });
  }, []);

  return (
    <>
      <Warning
        heading={heading}
        actionText={actionText}
        actionOnClick={actionOnClick}
        location="doc_auth_review_issues"
        troubleshootingOptions={
          <DocumentCaptureTroubleshootingOptions
            location="post_submission_warning"
            showAlternativeProofingOptions={!isFailedResult}
            showSPOption={!nonIppOrFailedResult}
            heading={t('components.troubleshooting_options.ipp_heading')}
          />
        }
      >
        <div ref={subheadingRef}>{!!subheading && subheading}</div>
        <div ref={errorMessageDisplayedRef}>
          <UnknownError
            unknownFieldErrors={unknownFieldErrors}
            remainingAttempts={remainingAttempts}
            isFailedDocType={isFailedDocType}
            selfieResultNotLiveOrPoorQuality={selfieResultNotLiveOrPoorQuality}
            hasDismissed={hasDismissed}
          />
        </div>

        {showRemainingAttemptsComponent({ isFailedDocType, remainingAttempts }) && (
          <p>
            <HtmlTextWithStrongNoWrap
              text={t('idv.failure.attempts_html', { count: remainingAttempts })}
            />
          </p>
        )}
      </Warning>
      {nonIppOrFailedResult && <Cancel />}
    </>
  );
}

export default DocumentCaptureWarning;
