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
import { SelfieStepComponent } from './selfie-step';
import TipList from './tip-list';
import {
  ImageValue,
  DefaultSideProps,
  DocumentsAndSelfieStepValue,
} from '../interface/documents-image-selfie-value';
import { DeviceContext, SelfieCaptureContext, UploadContext } from '../context';
import DocumentSideAcuantCapture from './document-side-acuant-capture';

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
export function DocumentsStep({
  defaultSideProps,
  value,
}: {
  defaultSideProps: DefaultSideProps;
  value: Record<string, ImageValue>;
}) {
  type DocumentSide = 'front' | 'back';
  const documentsSides: DocumentSide[] = ['front', 'back'];
  return (
    <>
      {documentsSides.map((side) => (
        <DocumentSideAcuantCapture
          {...defaultSideProps}
          key={side}
          side={side}
          value={value[side]}
        />
      ))}
    </>
  );
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
  const { isLastStep } = useContext(FormStepsContext);
  const { flowPath } = useContext(UploadContext);
  const { isSelfieCaptureEnabled } = useContext(SelfieCaptureContext);
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
      {isSelfieCaptureEnabled && (
        <SelfieStepComponent defaultSideProps={defaultSideProps} selfieValue={value.selfie} />
      )}
      {isLastStep ? <FormStepsButton.Submit /> : <FormStepsButton.Continue />}
      <Cancel />
    </>
  );
}
