import { useContext } from 'react';
import { PageHeading } from '@18f/identity-components';
import { FormStepsButton } from '@18f/identity-form-steps';
import { Cancel } from '@18f/identity-verify-flow';
import { useI18n, HtmlTextWithStrongNoWrap } from '@18f/identity-react-i18n';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import GeneralError from './general-error';
import { SelfieCaptureContext, UploadContext } from '../context';
import { DocumentCaptureSubheaderOne, DocumentsCaptureStep } from './documents-step';
import { SelfieCaptureStep } from './selfie-step';
import type { ReviewIssuesStepValue } from './review-issues-step';

interface DocumentCaptureReviewIssuesProps extends FormStepComponentProps<ReviewIssuesStepValue> {
  isFailedSelfie: boolean;
  isFailedDocType: boolean;
  isFailedSelfieLivenessOrQuality: boolean;
  remainingSubmitAttempts: number;
  hasDismissed: boolean;
}

function DocumentCaptureReviewIssues({
  isFailedDocType,
  isFailedSelfie,
  isFailedSelfieLivenessOrQuality,
  remainingSubmitAttempts = Infinity,
  registerField = () => undefined,
  unknownFieldErrors = [],
  errors = [],
  onChange = () => undefined,
  onError = () => undefined,
  value,
  hasDismissed,
}: DocumentCaptureReviewIssuesProps) {
  const { t } = useI18n();
  const { isSelfieCaptureEnabled } = useContext(SelfieCaptureContext);
  const { idType } = useContext(UploadContext);
  const idIsPassport = idType === 'passport';

  const pageHeading = idIsPassport ?
    t('doc_auth.headings.review_issues_passport') :
    t('doc_auth.headings.review_issues');

  const defaultSideProps = {
    registerField,
    onChange,
    errors,
    onError,
  };

  return (
    <>
      <PageHeading>{pageHeading}</PageHeading>
      {isSelfieCaptureEnabled && <DocumentCaptureSubheaderOne />}
      <GeneralError
        unknownFieldErrors={unknownFieldErrors}
        isFailedDocType={isFailedDocType}
        isFailedSelfie={isFailedSelfie}
        isFailedSelfieLivenessOrQuality={isFailedSelfieLivenessOrQuality}
        altIsFailedSelfieDontIncludeAttempts
        altFailedDocTypeMsg={isFailedDocType ? t('doc_auth.errors.doc.doc_type_check') : null}
        hasDismissed={hasDismissed}
      />
      {Number.isFinite(remainingSubmitAttempts) && !idIsPassport && (
        <p>
          <HtmlTextWithStrongNoWrap
            text={t('idv.failure.attempts_html', { count: remainingSubmitAttempts })}
          />
        </p>
      )}
      {idIsPassport && 
        <p>
          {t('doc_auth.info.review_passport')}
        </p>
      }
      <DocumentsCaptureStep defaultSideProps={defaultSideProps} value={value} isReviewStep />
      {isSelfieCaptureEnabled && (
        <SelfieCaptureStep
          defaultSideProps={defaultSideProps}
          selfieValue={value.selfie}
          isReviewStep
          showHelp={false}
          showSelfieHelp={() => undefined}
        />
      )}
      <FormStepsButton.Submit />
      <Cancel />
    </>
  );
}

export default DocumentCaptureReviewIssues;
