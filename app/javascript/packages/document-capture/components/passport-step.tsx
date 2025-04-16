import { useContext, useState } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import {
  FormStepComponentProps,
  FormStepsButton,
  FormStepsContext,
} from '@18f/identity-form-steps';
import { Cancel } from '@18f/identity-verify-flow';
import { SpinnerButton } from '@18f/identity-spinner-button';
import HybridDocCaptureWarning from './hybrid-doc-capture-warning';
import TipList from './tip-list';
import { DeviceContext, UploadContext } from '../context';
import {
  ImageValue,
  DefaultSideProps,
  DocumentsAndSelfieStepValue,
} from '../interface/documents-image-selfie-value';
import DocumentSideAcuantCapture from './document-side-acuant-capture';
import AcuantPassportInstructions from './acuant-passport-instructions';

export function PassportCaptureStep({
  defaultSideProps,
  passportValue,
  showHelp,
  isReviewStep = false,
}: {
  defaultSideProps: DefaultSideProps;
  passportValue: ImageValue;
  showHelp: boolean;
  isReviewStep: boolean;
}) {
  return (
    <>
      {showHelp && <AcuantPassportInstructions />}
      {!showHelp && (
        <DocumentSideAcuantCapture
          {...defaultSideProps}
          key="passport"
          side="passport"
          value={passportValue}
          isReviewStep={isReviewStep}
          showSelfieHelp={() => undefined}
        />
      )}
    </>
  );
}

export function PassportCaptureSubheaderOne() {
  const { t } = useI18n();
  return <h1>{t('doc_auth.headings.passport_capture')}</h1>;
}

export function PassportCaptureInfo() {
  const { t } = useI18n();
  return <p>{t('doc_auth.info.passport_capture')}</p>;
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
  const [showHelp, setShowHelp] = useState(isMobile);

  const defaultSideProps: DefaultSideProps = {
    registerField,
    onChange,
    errors,
    onError,
  };

  function TakePassportButton() {
    return (
      <div className="margin-y-5 ">
        <SpinnerButton
          spinOnClick={false}
          onClick={() => {
            setShowHelp(false);
          }}
          type="button"
          isBig
          isWide
        >
          {t('doc_auth.buttons.take_picture')}
        </SpinnerButton>
      </div>
    );
  }

  return (
    <>
      {flowPath === 'hybrid' && <HybridDocCaptureWarning className="margin-bottom-4" />}
      <PassportCaptureSubheaderOne />
      <PassportCaptureInfo />
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
        showHelp={isMobile}
        isReviewStep={false}
      />
      {isMobile && <TakePassportButton />}
      {!isMobile && (isLastStep ? <FormStepsButton.Submit /> : <FormStepsButton.Continue />)}
      <Cancel />
    </>
  );
}
