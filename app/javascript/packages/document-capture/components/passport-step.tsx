import { useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import {
  FormStepComponentProps,
  FormStepsButton,
  FormStepsContext,
} from '@18f/identity-form-steps';
import { Cancel } from '@18f/identity-verify-flow';
import HybridDocCaptureWarning from './hybrid-doc-capture-warning';
import TipList from './tip-list';
import { DeviceContext, UploadContext } from '../context';
import {
  ImageValue,
  DefaultSideProps,
  DocumentsAndSelfieStepValue,
} from '../interface/documents-image-selfie-value';
import DocumentSideAcuantCapture from './document-side-acuant-capture';

export function PassportCaptureStep({
  defaultSideProps,
  passportValue,
  isReviewStep = false,
}: {
  defaultSideProps: DefaultSideProps;
  passportValue: ImageValue;
  isReviewStep: boolean;
}) {
  return (
    <DocumentSideAcuantCapture
      {...defaultSideProps}
      key="passport"
      side="passport"
      value={passportValue}
      isReviewStep={isReviewStep}
      showSelfieHelp={() => undefined}
    />
  );
}

export function PassportCaptureSubheaderOne() {
  const { t } = useI18n();
  return <h1>{t('doc_auth.headings.document_capture_passport')}</h1>;
}

export default function PassportStep({
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
      <PassportCaptureSubheaderOne />
      <TipList
        titleClassName="margin-bottom-0 text-bold"
        title={t('doc_auth.tips.document_capture_selfie_id_header_text')}
        items={[
          t('doc_auth.tips.document_capture_id_text1'),
          t('doc_auth.tips.document_capture_id_text2'),
          t('doc_auth.tips.document_capture_id_text3'),
        ].concat(!isMobile ? [t('doc_auth.tips.document_capture_id_text4')] : [])}
      />
      <PassportCaptureStep
        defaultSideProps={defaultSideProps}
        passportValue={value.passport}
        isReviewStep={false}
      />
      {isLastStep ? <FormStepsButton.Submit /> : <FormStepsButton.Continue />}
      <Cancel />
    </>
  );
}
