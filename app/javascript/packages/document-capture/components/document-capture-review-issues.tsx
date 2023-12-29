import { useContext } from 'react';
import { PageHeading } from '@18f/identity-components';
import { FormStepsButton } from '@18f/identity-form-steps';
import { Cancel } from '@18f/identity-verify-flow';
import { useI18n } from '@18f/identity-react-i18n';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import UnknownError from './unknown-error';
import TipList from './tip-list';
import DocumentCaptureNotReady from './document-capture-not-ready';
import { FeatureFlagContext } from '../context';
import DocumentCaptureAbandon from './document-capture-abandon';
import {
  DocumentCaptureSubheaderOne,
  SelfieCaptureWithHeader,
  DocumentFrontAndBackCapture
} from './documents-step';
import type { ReviewIssuesStepValue } from './review-issues-step';

interface DocumentCaptureReviewIssuesProps
  extends Omit<FormStepComponentProps<ReviewIssuesStepValue>, 'toPreviousStep'> {
  isFailedDocType: boolean;
  remainingAttempts: number;
  captureHints: boolean;
  hasDismissed: boolean;
}

function DocumentCaptureReviewIssues({
  isFailedDocType,
  remainingAttempts = Infinity,
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
  const { notReadySectionEnabled, exitQuestionSectionEnabled, selfieCaptureEnabled } =
    useContext(FeatureFlagContext);

  const defaultSideProps = {
    registerField,
    onChange,
    errors,
    onError,
  }

  return (
    <>
      <PageHeading>{t('doc_auth.headings.review_issues')}</PageHeading>
      <DocumentCaptureSubheaderOne selfieCaptureEnabled={selfieCaptureEnabled} />
      <UnknownError
        unknownFieldErrors={unknownFieldErrors}
        remainingAttempts={remainingAttempts}
        isFailedDocType={isFailedDocType}
        altFailedDocTypeMsg={isFailedDocType ? t('doc_auth.errors.doc.wrong_id_type_html') : null}
        hasDismissed={hasDismissed}
      />
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
      <DocumentFrontAndBackCapture defaultSideProps={defaultSideProps} value={value} />
      {selfieCaptureEnabled && (
        <SelfieCaptureWithHeader defaultSideProps={defaultSideProps} selfieValue={value.selfie}/>
      )}
      <FormStepsButton.Submit />
      {notReadySectionEnabled && <DocumentCaptureNotReady />}
      {exitQuestionSectionEnabled && <DocumentCaptureAbandon />}
      <Cancel />
    </>
  );
}

export default DocumentCaptureReviewIssues;
