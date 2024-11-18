import { useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { FormStepComponentProps, FormStepsButton, FormStepsContext } from '@18f/identity-form-steps';
import { Cancel } from '@18f/identity-verify-flow';
import HybridDocCaptureWarning from './hybrid-doc-capture-warning';
import TipList from './tip-list';
import { DeviceContext, UploadContext } from '../context';
import { ImageValue, DefaultSideProps, DocumentsAndSelfieStepValue } from '../interface/documents-image-selfie-value';
import DocumentSideAcuantCapture from './document-side-acuant-capture';

export function DocumentsCaptureStep({
  defaultSideProps,
  value,
  isReviewStep = false,
}: {
  defaultSideProps: DefaultSideProps;
  value: Record<string, ImageValue>;
  isReviewStep: boolean;
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
          isReviewStep={isReviewStep}
        />
      ))}
    </>
  );
}

export function DocumentCaptureSubheaderOne() {
  const { t } = useI18n();
  return <h1>{t('doc_auth.headings.document_capture')}</h1>;
}

export default function DocumentsStep({
  value = {},
  onChange = () => {},
  errors = [],
  onError = () => {},
  registerField = () => undefined,
}: FormStepComponentProps<DocumentsAndSelfieStepValue>) {
  const { t } = useI18n();
  const { isLastStep } = useContext(FormStepsContext);
  const { isMobile } = useContext(DeviceContext);
  const { flowPath } = useContext(UploadContext);
  const defaultSideProps: DefaultSideProps = {
    registerField,
    onChange,
    errors,
    onError,
  };
  return (
    <>
      {flowPath === 'hybrid' && <HybridDocCaptureWarning className="margin-bottom-4" />}
      <DocumentCaptureSubheaderOne />
      <TipList
        titleClassName="margin-bottom-0 text-bold"
        title={t('doc_auth.tips.document_capture_selfie_id_header_text')}
        items={[
          t('doc_auth.tips.document_capture_id_text1'),
          t('doc_auth.tips.document_capture_id_text2'),
          t('doc_auth.tips.document_capture_id_text3'),
        ].concat(!isMobile ? [t('doc_auth.tips.document_capture_id_text4')] : [])}
      />
      <DocumentsCaptureStep defaultSideProps={defaultSideProps} value={value} isReviewStep={false} />
      {isLastStep ? <FormStepsButton.Submit /> : <FormStepsButton.Continue />}
      <Cancel />
    </>
  );
}
