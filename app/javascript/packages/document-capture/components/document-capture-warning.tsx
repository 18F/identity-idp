import { Cancel } from '@18f/identity-verify-flow';
import { useI18n, HtmlTextWithStrongNoWrap } from '@18f/identity-react-i18n';
import { useContext, useEffect, useRef } from 'react';
import { FormStepError } from '@18f/identity-form-steps';
import type { I18n } from '@18f/identity-i18n';
import Warning from './warning';
import DocumentCaptureTroubleshootingOptions from './document-capture-troubleshooting-options';
import GeneralError from './general-error';
import { InPersonContext } from '../context';
import AnalyticsContext from '../context/analytics';
import SelfieCaptureContext from '../context/selfie-capture';

interface DocumentCaptureWarningProps {
  isResultCodeInvalid: boolean;
  isFailedDocType: boolean;
  isFailedResult: boolean;
  isFailedSelfie: boolean;
  isFailedSelfieLivenessOrQuality: boolean;
  remainingSubmitAttempts: number;
  actionOnClick?: () => void;
  unknownFieldErrors: FormStepError<{ front: string; back: string }>[];
  hasDismissed: boolean;
}

type GetHeadingArguments = {
  isResultCodeInvalid: boolean;
  isFailedDocType: boolean;
  isFailedSelfie: boolean;
  isFailedSelfieLivenessOrQuality: boolean;
  t: typeof I18n.prototype.t;
};
function getHeading({
  isResultCodeInvalid,
  isFailedDocType,
  isFailedSelfie,
  isFailedSelfieLivenessOrQuality,
  t,
}: GetHeadingArguments) {
  if (isFailedDocType) {
    return t('doc_auth.errors.doc_type_not_supported_heading');
  }
  if (isResultCodeInvalid) {
    return t('doc_auth.errors.rate_limited_heading');
  }
  if (isFailedSelfieLivenessOrQuality) {
    return t('doc_auth.errors.selfie_not_live_or_poor_quality_heading');
  }
  if (isFailedSelfie) {
    return t('doc_auth.errors.selfie_fail_heading');
  }
  return t('doc_auth.errors.rate_limited_heading');
}

function getSubheading({ nonIppOrFailedResult, t }) {
  const showSubheading = !nonIppOrFailedResult;

  if (showSubheading) {
    return <h2>{t('doc_auth.errors.rate_limited_subheading')}</h2>;
  }
  return undefined;
}

function DocumentCaptureWarning({
  isResultCodeInvalid,
  isFailedDocType,
  isFailedResult,
  isFailedSelfie,
  isFailedSelfieLivenessOrQuality,
  remainingSubmitAttempts,
  actionOnClick,
  unknownFieldErrors = [],
  hasDismissed,
}: DocumentCaptureWarningProps) {
  const { t } = useI18n();
  const { inPersonURL } = useContext(InPersonContext);
  const { isSelfieCaptureEnabled } = useContext(SelfieCaptureContext);
  const { trackEvent } = useContext(AnalyticsContext);

  const nonIppOrFailedResult = !inPersonURL || isFailedResult;
  const heading = getHeading({
    isResultCodeInvalid,
    isFailedDocType,
    isFailedSelfie,
    isFailedSelfieLivenessOrQuality,
    t,
  });
  const actionText = nonIppOrFailedResult
    ? t('idv.failure.button.warning')
    : t('idv.failure.button.try_online');
  const subheading = getSubheading({
    nonIppOrFailedResult,
    t,
  });
  const subheadingRef = useRef<HTMLDivElement>(null);
  const errorMessageDisplayedRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const subheadingText = subheadingRef.current?.textContent;
    const errorMessageDisplayed = errorMessageDisplayedRef.current?.textContent;

    trackEvent('IdV: warning shown', {
      location: 'doc_auth_review_issues',
      remaining_submit_attempts: remainingSubmitAttempts,
      heading,
      subheading: subheadingText,
      error_message_displayed: errorMessageDisplayed,
      liveness_checking_required: isSelfieCaptureEnabled,
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
            heading={t('components.troubleshooting_options.ipp_heading')}
          />
        }
      >
        <div ref={subheadingRef}>{!!subheading && subheading}</div>
        <div ref={errorMessageDisplayedRef}>
          <GeneralError
            unknownFieldErrors={unknownFieldErrors}
            isFailedDocType={isFailedDocType}
            isFailedSelfie={isFailedSelfie}
            isFailedSelfieLivenessOrQuality={isFailedSelfieLivenessOrQuality}
            hasDismissed={hasDismissed}
          />
        </div>
        <p>
          <HtmlTextWithStrongNoWrap
            text={t('idv.failure.attempts_html', { count: remainingSubmitAttempts })}
          />
        </p>
      </Warning>
      {nonIppOrFailedResult && <Cancel />}
    </>
  );
}

export default DocumentCaptureWarning;
