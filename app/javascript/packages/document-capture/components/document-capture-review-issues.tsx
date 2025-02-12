import { useContext } from 'react';
import { PageHeading } from '@18f/identity-components';
import { FormStepsButton } from '@18f/identity-form-steps';
import { Cancel } from '@18f/identity-verify-flow';
import { useI18n, HtmlTextWithStrongNoWrap } from '@18f/identity-react-i18n';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import GeneralError from './general-error';
import TipList from './tip-list';
import { SelfieCaptureContext } from '../context';
import { DocumentCaptureSubheaderOne, DocumentsCaptureStep } from './documents-step';
import { SelfieCaptureStep } from './selfie-step';
import type { ReviewIssuesStepValue } from './review-issues-step';

interface DocumentCaptureReviewIssuesProps extends FormStepComponentProps<ReviewIssuesStepValue> {
  isFailedSelfie: boolean;
  isFailedDocType: boolean;
  isFailedSelfieLivenessOrQuality: boolean;
  remainingSubmitAttempts: number;
  captureHints: boolean;
  hasDismissed: boolean;
}

function DocumentCaptureReviewIssues({
  isFailedDocType,
  isFailedSelfie,
  isFailedSelfieLivenessOrQuality,
  remainingSubmitAttempts = Infinity,
  captureHints,
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

  const defaultSideProps = {
    registerField,
    onChange,
    errors,
    onError,
  };

  return (
    <>
      <PageHeading>{t('doc_auth.headings.review_issues')}</PageHeading>
      {isSelfieCaptureEnabled && <DocumentCaptureSubheaderOne />}
      <GeneralError
        unknownFieldErrors={unknownFieldErrors}
        isFailedDocType={isFailedDocType}
        isFailedSelfie={isFailedSelfie}
        isFailedSelfieLivenessOrQuality={isFailedSelfieLivenessOrQuality}
        altIsFailedSelfieDontIncludeAttempts
        altFailedDocTypeMsg={isFailedDocType ? t('doc_auth.errors.doc.wrong_id_type_html') : null}
        hasDismissed={hasDismissed}
      />
      {Number.isFinite(remainingSubmitAttempts) && (
        <p>
          <HtmlTextWithStrongNoWrap
            text={t('idv.failure.attempts_html', { count: remainingSubmitAttempts })}
          />
        </p>
      )}
      {!isFailedDocType && captureHints && (
        <TipList
          titleClassName="margin-bottom-0 margin-top-2"
          title={t('doc_auth.tips.review_issues_id_header_text')}
          items={[
            t('doc_auth.tips.review_issues_id_text1'),
            t('doc_auth.tips.review_issues_id_text2'),
            t('doc_auth.tips.review_issues_id_text3'),
            t('doc_auth.tips.review_issues_id_text4'),
          ]}
        />
      )}
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
