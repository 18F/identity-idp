import { FormStepError, OnErrorCallback, RegisterFieldCallback } from '@18f/identity-form-steps';
import { useI18n } from '@18f/identity-react-i18n';
import DocumentSideAcuantCapture from './document-side-acuant-capture';
import TipList from './tip-list';
import withProps from '../higher-order/with-props';

interface DocumentCaptureSelfieCaptureProps {
  registerField: RegisterFieldCallback;
  value: Blob | string | null | undefined;
  onChange: (nextValues: { [key: string]: Blob | string | null | undefined }) => void;
  errors: FormStepError<any>[];
  onError?: OnErrorCallback;
  className?: string;
}

/**
 * @param {DocumentCaptureSelfieCaptureProps} props Props object.
 */
function DocumentCaptureSelfieCapture({
  registerField,
  value,
  onChange,
  errors,
  onError,
  className,
}: DocumentCaptureSelfieCaptureProps) {
  const { t } = useI18n();
  const SelfieTipList = withProps({
    title: t('doc_auth.tips.document_capture_selfie_selfie_text'),
    titleClassName: 'margin-bottom-0 text-bold',
    items: [
      t('doc_auth.tips.document_capture_selfie_text1'),
      t('doc_auth.tips.document_capture_selfie_text2'),
      t('doc_auth.tips.document_capture_selfie_text3'),
    ],
  })(TipList);
  const Selfie = withProps({
    key: 'selfie',
    side: 'selfie',
    value,
    registerField,
    onChange,
    errors,
    onError,
    className,
  })(DocumentSideAcuantCapture);

  return (
    <>
      <hr className="margin-y-5" />
      <h2>2. {t('doc_auth.headings.document_capture_subheader_selfie')}</h2>
      <SelfieTipList />
      <Selfie />
    </>
  );
}

export default DocumentCaptureSelfieCapture;
