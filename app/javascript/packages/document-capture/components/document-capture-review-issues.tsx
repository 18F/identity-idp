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
import { UIConfigContext } from '../context';

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

type DocumentSide = 'front' | 'back';

/**
 * Sides of the document to present as file input.
 */
const DOCUMENT_SIDES: DocumentSide[] = ['front', 'back'];
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
  const { notReadySectionEnabled } = useContext(UIConfigContext);
  return (
    <>
      <PageHeading>{t('doc_auth.headings.review_issues')}</PageHeading>
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
      {notReadySectionEnabled && <DocumentCaptureNotReady />}
      <Cancel />
    </>
  );
}

export default DocumentCaptureReviewIssues;
