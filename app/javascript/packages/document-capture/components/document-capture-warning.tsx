import { Cancel } from '@18f/identity-verify-flow';
import { useI18n, HtmlTextWithStrongNoWrap } from '@18f/identity-react-i18n';
import { useContext, useEffect, useRef } from 'react';
import { FormStepError } from '@18f/identity-form-steps';
import type { I18n } from '@18f/identity-i18n';
import Warning from './warning';
import DocumentCaptureTroubleshootingOptions from './document-capture-troubleshooting-options';
import UnknownError from './unknown-error';
import { InPersonContext } from '../context';
import AnalyticsContext from '../context/analytics';

interface DocumentCaptureWarningProps {
  isFailedDocType: boolean;
  isFailedResult: boolean;
  isFailedSelfieLivenessOrQuality: boolean;
  remainingAttempts: number;
  actionOnClick?: () => void;
  unknownFieldErrors: FormStepError<{ front: string; back: string }>[];
  hasDismissed: boolean;
}

const DISPLAY_ATTEMPTS = 3;

type GetHeadingArguments = {
  isFailedDocType: boolean;
  isFailedSelfieLivenessOrQuality: boolean;
  t: typeof I18n.prototype.t;
};
function getHeading({ isFailedDocType, isFailedSelfieLivenessOrQuality, t }: GetHeadingArguments) {
  if (isFailedDocType) {
    return t('errors.doc_auth.doc_type_not_supported_heading');
  }
  if (isFailedSelfieLivenessOrQuality) {
    return t('errors.doc_auth.selfie_not_live_or_poor_quality_heading');
  }
  return t('errors.doc_auth.rate_limited_heading');
}

function DocumentCaptureWarning({
  isFailedDocType,
  isFailedResult,
  isFailedSelfieLivenessOrQuality,
  remainingAttempts,
  actionOnClick,
  unknownFieldErrors = [],
  hasDismissed,
}: DocumentCaptureWarningProps) {
  const { t } = useI18n();
  const { inPersonURL } = useContext(InPersonContext);
  const { trackEvent } = useContext(AnalyticsContext);

  const nonIppOrFailedResult = !inPersonURL || isFailedResult;
  const heading = getHeading({ isFailedDocType, isFailedSelfieLivenessOrQuality, t });
  const actionText = nonIppOrFailedResult
    ? t('idv.failure.button.warning')
    : t('idv.failure.button.try_online');
  const subheading = !nonIppOrFailedResult &&
    !isFailedDocType &&
    !isFailedSelfieLivenessOrQuality && <h2>{t('errors.doc_auth.rate_limited_subheading')}</h2>;
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
            isFailedSelfieLivenessOrQuality={isFailedSelfieLivenessOrQuality}
            hasDismissed={hasDismissed}
          />
        </div>

        {!isFailedDocType &&
          !isFailedSelfieLivenessOrQuality &&
          remainingAttempts <= DISPLAY_ATTEMPTS && (
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
