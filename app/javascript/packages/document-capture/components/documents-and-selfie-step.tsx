import { useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import {
  FormStepComponentProps,
  FormStepsButton,
  FormStepsContext,
} from '@18f/identity-form-steps';
import { PageHeading } from '@18f/identity-components';
import { Cancel } from '@18f/identity-verify-flow';
import HybridDocCaptureWarning from './hybrid-doc-capture-warning';
import DocumentsStep from './documents-step';
import { SelfieStepComponent } from './selfie-step';
import TipList from './tip-list';
import { DefaultSideProps, DocumentsAndSelfieStepValue } from './documents-image-selfie-value';
import { DeviceContext, SelfieCaptureContext, UploadContext } from '../context';

export function DocumentCaptureSubheaderOne({
  isSelfieCaptureEnabled,
}: {
  isSelfieCaptureEnabled: boolean;
}) {
  const { t } = useI18n();
  return (
    <h2>
      <hr className="margin-y-5" />
      {isSelfieCaptureEnabled && '1. '}
      {t('doc_auth.headings.document_capture_subheader_id')}
    </h2>
  );
}
const appRoot = document.getElementById('document-capture-form')!;

function getDocAuthSeparatePagesEnabled() {
  if (appRoot == null) {
    return false;
  }
  if (appRoot.dataset == null) {
    return false;
  }

  const { docAuthSeparatePagesEnabled } = appRoot.dataset;
  return docAuthSeparatePagesEnabled === 'true';
}

export default function DocumentsAndSelfieStep({
  value = {},
  onChange = () => {},
  errors = [],
  onError = () => {},
  registerField = () => undefined,
}: FormStepComponentProps<DocumentsAndSelfieStepValue>) {
  const { t } = useI18n();
  const { isMobile } = useContext(DeviceContext);
  const { isLastStep, changeStepCanComplete } = useContext(FormStepsContext);
  const { flowPath } = useContext(UploadContext);
  const { isSelfieCaptureEnabled } = useContext(SelfieCaptureContext);
  const docAuthSeparatePagesEnabled = getDocAuthSeparatePagesEnabled();
  if (isSelfieCaptureEnabled && docAuthSeparatePagesEnabled) {
    changeStepCanComplete(false);
  }
  const pageHeaderText = isSelfieCaptureEnabled
    ? t('doc_auth.headings.document_capture_with_selfie')
    : t('doc_auth.headings.document_capture');

  const defaultSideProps: DefaultSideProps = {
    registerField,
    onChange,
    errors,
    onError,
  };
  return (
    <>
      {flowPath === 'hybrid' && <HybridDocCaptureWarning className="margin-bottom-4" />}
      <PageHeading>{pageHeaderText}</PageHeading>
      {isSelfieCaptureEnabled && (
        <DocumentCaptureSubheaderOne isSelfieCaptureEnabled={isSelfieCaptureEnabled} />
      )}
      <TipList
        titleClassName="margin-bottom-0 text-bold"
        title={t('doc_auth.tips.document_capture_selfie_id_header_text')}
        items={[
          t('doc_auth.tips.document_capture_id_text1'),
          t('doc_auth.tips.document_capture_id_text2'),
          t('doc_auth.tips.document_capture_id_text3'),
        ].concat(!isMobile ? [t('doc_auth.tips.document_capture_id_text4')] : [])}
      />
      <DocumentsStep defaultSideProps={defaultSideProps} value={value} />
      {isSelfieCaptureEnabled && !docAuthSeparatePagesEnabled && (
        <SelfieStepComponent defaultSideProps={defaultSideProps} selfieValue={value.selfie} />
      )}
      {isLastStep ? <FormStepsButton.Submit /> : <FormStepsButton.Continue />}
      <Cancel />
    </>
  );
}
