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
import MarketingSiteContext from '../context/marketing-site';
import UnknownError from './unknown-error';
import TipList from './tip-list';
import DocumentSideAcuantCapture from './document-side-acuant-capture';

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
}: DocumentCaptureReviewIssuesProps) {
  const { getHelpCenterURL } = useContext(MarketingSiteContext);
  const { t } = useI18n();
  return (
    <>
      <PageHeading>{t('doc_auth.headings.review_issues')}</PageHeading>
      <UnknownError
        unknownFieldErrors={unknownFieldErrors}
        remainingAttempts={remainingAttempts}
        isFailedDocType={isFailedDocType}
        altFailedDocTypeMsg={isFailedDocType ? t('doc_auth.errors.doc.wrong_id_type') : null}
      />
      {!isFailedDocType && (
        <a
          href={getHelpCenterURL({
            category: 'verify-your-identity',
            article: 'how-to-add-images-of-your-state-issued-id',
            location: 'document_capture_review_issues',
          })}
        >
          &nbsp; {t('doc_auth.info.review_examples_of_photos')}
        </a>
      )}
      {!isFailedDocType && captureHints && (
        <TipList
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
      <Cancel />
    </>
  );
}

export default DocumentCaptureReviewIssues;
