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

  const pageHeading = isReviewStep
    ? t('doc_auth.headings.document_capture_subheader_selfie_review')
    : t('doc_auth.headings.document_capture_subheader_selfie');
  return (
    <>
      {!isReviewStep && (
        <div className="ads-auth__header">
          <div className="ads-auth__intro">
            <h1>{pageHeading}</h1>
            <p className="ads-auth__intro-description">
              {t('doc_auth.info.selfie_capture_content')}
            </p>
          </div>
        </div>
      )}
      {isReviewStep && (
        <>
          <h2>{pageHeading}</h2>
          <p>{t('doc_auth.info.selfie_capture_content')}</p>
        </>
      )}
      <div className="ads-auth__form-page-body">
        <div className="ads-stack ads-stack--gap-24 ads-stack--align-stretch">
          <TipList
            title={t('doc_auth.tips.document_capture_selfie_selfie_text')}
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
        </div>
      </div>
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
      <div className="ads-actions ads-actions--align-stretch">
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
      {flowPath === 'hybrid' && <HybridDocCaptureWarning />}
      <SelfieCaptureStep
        defaultSideProps={defaultSideProps}
        selfieValue={value.selfie}
        isReviewStep={false}
        showHelp={showHelp}
        showSelfieHelp={showSelfieHelp}
      />
      {showHelp && <TakeSelfieButton />}
      {!showHelp && (
        <div className="ads-actions ads-actions--gap-8 ads-actions--align-stretch">
          {isLastStep ? <FormStepsButton.Submit /> : <FormStepsButton.Continue />}
          <Cancel />
        </div>
      )}
    </>
  );
}
