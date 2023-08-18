import { Cancel } from '@18f/identity-verify-flow';
import { useI18n, HtmlTextWithStrongNoWrap } from '@18f/identity-react-i18n';
import { useContext } from 'react';
import { FormStepError } from '@18f/identity-form-steps';
import Warning from './warning';
import DocumentCaptureTroubleshootingOptions from './document-capture-troubleshooting-options';
import UnknownError from './unknown-error';
import { InPersonContext } from '../context';

interface DocumentCaptureWarningProps {
  isFailedDocType: boolean;
  isFailedResult: boolean;
  remainingAttempts: number;
  actionOnClick?: () => void;
  unknownFieldErrors: FormStepError<{ front: string; back: string; general?: string }>[];
}

const DISPLAY_ATTEMPTS = 3;

function DocumentCaptureWarning({
  isFailedDocType,
  isFailedResult,
  remainingAttempts,
  actionOnClick,
  unknownFieldErrors = [],
}: DocumentCaptureWarningProps) {
  const { t } = useI18n();
  const { inPersonURL } = useContext(InPersonContext);

  const nonIppOrFailedResult = !inPersonURL || isFailedResult;
  const heading = isFailedDocType
    ? t('errors.doc_auth.doc_type_not_supported_heading')
    : t('errors.doc_auth.rate_limited_heading');
  const actionText = nonIppOrFailedResult
    ? t('idv.failure.button.warning')
    : t('idv.failure.button.try_online');
  const subHeading = !nonIppOrFailedResult && !isFailedDocType && (
    <h2>{t('errors.doc_auth.rate_limited_subheading')}</h2>
  );
  return (
    <>
      <Warning
        heading={heading}
        actionText={actionText}
        actionOnClick={actionOnClick}
        location="doc_auth_review_issues"
        remainingAttempts={remainingAttempts}
        troubleshootingOptions={
          <DocumentCaptureTroubleshootingOptions
            location="post_submission_warning"
            showAlternativeProofingOptions={!isFailedResult}
            showSPOption={!nonIppOrFailedResult}
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
