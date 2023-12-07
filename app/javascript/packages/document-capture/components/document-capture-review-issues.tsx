import { useContext } from 'react';
import { PageHeading } from '@18f/identity-components';
import {
  FormStepError,
  FormStepsButton,
  OnErrorCallback,
  RegisterFieldCallback,
} from '@18f/identity-form-steps';
import { Cancel } from '@18f/identity-verify-flow';
import { useI18n } from '@18f/identity-react-i18n';
import UnknownError from './unknown-error';
import TipList from './tip-list';
import DocumentSideAcuantCapture from './document-side-acuant-capture';
import DocumentCaptureNotReady from './document-capture-not-ready';
import { FeatureFlagContext } from '../context';
import DocumentCaptureAbandon from './document-capture-abandon';
import DocumentCaptureSelfieCapture from './document-capture-selfie-capture';

interface DocumentCaptureReviewIssuesProps {
  isFailedDocType: boolean;
  remainingAttempts: number;
  captureHints: boolean;
  registerField: RegisterFieldCallback;
  value: { string: Blob | string | null | undefined } | {};
  unknownFieldErrors: FormStepError<any>[];
  errors: FormStepError<any>[];
  onChange: (...args: any) => void;
  onError: OnErrorCallback;
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
  value = {},
  hasDismissed,
}: DocumentCaptureReviewIssuesProps) {
  const { t } = useI18n();
  const { notReadySectionEnabled, exitQuestionSectionEnabled, selfieCaptureEnabled } =
    useContext(FeatureFlagContext);

  // Sides of document to present as file input.
  const documentSides: ('front' | 'back')[] = ['front', 'back'];
  const selfieSide = 'selfie';

  const pageHeaderText = selfieCaptureEnabled
    ? t('doc_auth.headings.document_capture_with_selfie')
    : t('doc_auth.headings.review_issues');

  const idTipListTitle = selfieCaptureEnabled
    ? t('doc_auth.tips.document_capture_selfie_id_header_text')
    : t('doc_auth.tips.review_issues_id_header_text');

  return (
    <>
      <PageHeading>{pageHeaderText}</PageHeading>
      <UnknownError
        unknownFieldErrors={unknownFieldErrors}
        remainingAttempts={remainingAttempts}
        isFailedDocType={isFailedDocType}
        altFailedDocTypeMsg={isFailedDocType ? t('doc_auth.errors.doc.wrong_id_type_html') : null}
        hasDismissed={hasDismissed}
      />
      {selfieCaptureEnabled && <h2>{t('doc_auth.headings.document_capture_subheader_id')}</h2>}
      {(selfieCaptureEnabled || (!isFailedDocType && captureHints)) && (
        <TipList
          titleClassName={`margin-bottom-0 margin-top-2 ${selfieCaptureEnabled ? 'text-bold' : ''}`}
          title={idTipListTitle}
          items={
            selfieCaptureEnabled
              ? [
                  t('doc_auth.tips.document_capture_id_text1'),
                  t('doc_auth.tips.document_capture_id_text2'),
                  t('doc_auth.tips.document_capture_id_text3'),
                ]
              : [
                  t('doc_auth.tips.review_issues_id_text1'),
                  t('doc_auth.tips.review_issues_id_text2'),
                  t('doc_auth.tips.review_issues_id_text3'),
                  t('doc_auth.tips.review_issues_id_text4'),
                ]
          }
        />
      )}
      {documentSides.map((side) => (
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
      {selfieCaptureEnabled && (
        <DocumentCaptureSelfieCapture
          registerField={registerField}
          value={value[selfieSide]}
          onChange={onChange}
          errors={errors}
          onError={onError}
        />
      )}
      <FormStepsButton.Submit />
      {notReadySectionEnabled && <DocumentCaptureNotReady />}
      {exitQuestionSectionEnabled && <DocumentCaptureAbandon />}
      <Cancel />
    </>
  );
}

export default DocumentCaptureReviewIssues;
