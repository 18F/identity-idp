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
import DocumentSideAcuantCapture from './document-side-acuant-capture';
import TipList from './tip-list';
import { DeviceContext, SelfieCaptureContext, UploadContext } from '../context';

export function DocumentCaptureSubheaderOne({
  isSelfieCaptureEnabled,
}: {
  isSelfieCaptureEnabled: boolean;
}) {
  const { t } = useI18n();
  return (
    <h2>
      {isSelfieCaptureEnabled && '1. '}
      {t('doc_auth.headings.document_capture_subheader_id')}
    </h2>
  );
}

export function SelfieCaptureWithHeader({
  defaultSideProps,
  selfieValue,
}: {
  defaultSideProps: DefaultSideProps;
  selfieValue: ImageValue;
}) {
  const { t } = useI18n();
  return (
    <>
      <hr className="margin-y-5" />
      <h2>2. {t('doc_auth.headings.document_capture_subheader_selfie')}</h2>
      <p>{t('doc_auth.info.selfie_capture_content')}</p>
      <TipList
        title={t('doc_auth.tips.document_capture_selfie_selfie_text')}
        titleClassName="margin-bottom-0 text-bold"
        items={[
          t('doc_auth.tips.document_capture_selfie_text1'),
          t('doc_auth.tips.document_capture_selfie_text2'),
          t('doc_auth.tips.document_capture_selfie_text3'),
          t('doc_auth.tips.document_capture_selfie_text4'),
        ]}
      />
      <DocumentSideAcuantCapture
        {...defaultSideProps}
        key="selfie"
        side="selfie"
        value={selfieValue}
      />
    </>
  );
}

export function DocumentFrontAndBackCapture({
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

type ImageValue = Blob | string | null | undefined;

interface DocumentsStepValue {
  front: ImageValue;
  back: ImageValue;
  selfie: ImageValue;
  front_image_metadata?: string;
  back_image_metadata?: string;
}

type DefaultSideProps = Pick<
  FormStepComponentProps<DocumentsStepValue>,
  'registerField' | 'onChange' | 'errors' | 'onError'
>;

export function DocumentsAndSelfieStep({
  value = {},
  onChange = () => {},
  errors = [],
  onError = () => {},
  registerField = () => undefined,
}: FormStepComponentProps<DocumentsStepValue>) {
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
      <DocumentFrontAndBackCapture defaultSideProps={defaultSideProps} value={value} />
      {isSelfieCaptureEnabled && (
        <SelfieCaptureWithHeader defaultSideProps={defaultSideProps} selfieValue={value.selfie} />
      )}
      {isLastStep ? <FormStepsButton.Submit /> : <FormStepsButton.Continue />}
      <Cancel />
    </>
  );
}
