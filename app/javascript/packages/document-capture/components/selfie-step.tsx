import { useContext, useState } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import {
  FormStepComponentProps,
  FormStepsButton,
  FormStepsContext,
} from '@18f/identity-form-steps';
import { Cancel } from '@18f/identity-verify-flow';
import { SpinnerButton } from '@18f/identity-spinner-button';
import AcuantSelfieInstructions from './acuant-selfie-instructions';
import SelfieCaptureContext from '../context/selfie-capture';
import HybridDocCaptureWarning from './hybrid-doc-capture-warning';
import DocumentSideAcuantCapture from './document-side-acuant-capture';
import TipList from './tip-list';
import { UploadContext } from '../context';
import {
  ImageValue,
  DefaultSideProps,
  DocumentsAndSelfieStepValue,
} from '../interface/documents-image-selfie-value';

export function SelfieCaptureStep({
  defaultSideProps,
  selfieValue,
  isReviewStep,
  showHelp,
  showSelfieHelp,
}: {
  defaultSideProps: DefaultSideProps;
  selfieValue: ImageValue;
  isReviewStep: boolean;
  showHelp: boolean;
  showSelfieHelp: () => void;
}) {
  const { t } = useI18n();

  return (
    <>
      <h1>{t('doc_auth.headings.document_capture_subheader_selfie')}</h1>
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

      {showHelp && <AcuantSelfieInstructions />}
      {!showHelp && (
        <DocumentSideAcuantCapture
          {...defaultSideProps}
          key="selfie"
          side="selfie"
          value={selfieValue}
          isReviewStep={isReviewStep}
          showSelfieHelp={showSelfieHelp}
        />
      )}
    </>
  );
}

export default function SelfieStep({
  value = {},
  onChange = () => {},
  errors = [],
  onError = () => {},
  registerField = () => undefined,
}: FormStepComponentProps<DocumentsAndSelfieStepValue>) {
  const { t } = useI18n();
  const { isLastStep } = useContext(FormStepsContext);
  const { flowPath } = useContext(UploadContext);
  const { showHelpInitially } = useContext(SelfieCaptureContext);
  const [showHelp, setShowHelp] = useState(showHelpInitially);

  const showSelfieHelp = () => {
    setShowHelp(true);
  };

  function TakeSelfieButton() {
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

  const defaultSideProps: DefaultSideProps = {
    registerField,
    onChange,
    errors,
    onError,
  };
  return (
    <>
      {flowPath === 'hybrid' && <HybridDocCaptureWarning className="margin-bottom-4" />}
      <SelfieCaptureStep
        defaultSideProps={defaultSideProps}
        selfieValue={value.selfie}
        isReviewStep={false}
        showHelp={showHelp}
        showSelfieHelp={showSelfieHelp}
      />
      {showHelp && <TakeSelfieButton />}
      {!showHelp && isLastStep && <FormStepsButton.Submit />}
      {!showHelp && !isLastStep && <FormStepsButton.Continue />}
      <Cancel />
    </>
  );
}
