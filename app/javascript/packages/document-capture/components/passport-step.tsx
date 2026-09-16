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
import { DeviceContext, UploadContext, PassportCaptureContext } from '../context';
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
  backValue,
  isPassportCard = false,
  showHelp,
  isReviewStep = false,
}: {
  defaultSideProps: DefaultSideProps;
  passportValue: ImageValue;
  backValue?: ImageValue;
  isPassportCard?: boolean;
  showHelp: boolean;
  isReviewStep: boolean;
}) {
  return (
    <>
      {showHelp && <AcuantPassportInstructions />}
      {!showHelp && (
        <>
          <DocumentSideAcuantCapture
            {...defaultSideProps}
            key="passport"
            side="passport"
            value={passportValue}
            isReviewStep={isReviewStep}
            showSelfieHelp={() => undefined}
          />
          {isPassportCard && (
            <DocumentSideAcuantCapture
              {...defaultSideProps}
              key="back"
              side="back"
              value={backValue}
              isReviewStep={isReviewStep}
              showSelfieHelp={() => undefined}
            />
          )}
        </>
      )}
    </>
  );
}

export function PassportCaptureSubheaderOne({
  isPassportCard = false,
}: {
  isPassportCard?: boolean;
}) {
  const { t } = useI18n();
  const heading = isPassportCard
    ? t('doc_auth.headings.passport_card_capture')
    : t('doc_auth.headings.passport_capture');
  return <h1>{heading}</h1>;
}

export function PassportCaptureInfo({
  isPassportCard = false,
}: {
  isPassportCard?: boolean;
}) {
  const { t } = useI18n();
  const content = isPassportCard
    ? t('doc_auth.info.passport_card_capture')
    : t('doc_auth.info.passport_capture');
  return <p>{content}</p>;
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
  const { flowPath, idType } = useContext(UploadContext);
  const { showHelpInitially } = useContext(PassportCaptureContext);
  const [showHelp, setShowHelp] = useState(showHelpInitially && isMobile);
  const isPassportCard = idType === 'passport_card';

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
      <PassportCaptureSubheaderOne isPassportCard={isPassportCard} />
      <PassportCaptureInfo isPassportCard={isPassportCard}/>
      {isMobile && (
        <TipList
          titleClassName="margin-bottom-0 text-bold"
          title={t('doc_auth.tips.document_capture_passport_header')}
          items={[
            t('doc_auth.tips.document_capture_passport_tip1'),
            t('doc_auth.tips.document_capture_passport_tip2'),
          ]}
        />
      )}
      {!isMobile && (
        <TipList
          titleClassName="margin-bottom-0 text-bold"
          title={t('doc_auth.tips.document_capture_selfie_id_header_text')}
          items={[
            t('doc_auth.tips.document_capture_id_text1'),
            t('doc_auth.tips.document_capture_id_text2'),
            t('doc_auth.tips.document_capture_id_text3'),
            t('doc_auth.tips.document_capture_id_text4'),
          ]}
        />
      )}
      <PassportCaptureStep
        defaultSideProps={defaultSideProps}
        passportValue={value.passport}
        backValue={value.back}
        isPassportCard={isPassportCard}
        showHelp={showHelp}
        isReviewStep={false}
      />
      {showHelp && <TakePassportButton />}
      {!showHelp && (isLastStep ? <FormStepsButton.Submit /> : <FormStepsButton.Continue />)}
      <Cancel />
    </>
  );
}
