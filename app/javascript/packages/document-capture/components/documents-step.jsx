import { useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { FormStepsButton, FormStepsContext } from '@18f/identity-form-steps';
import { PageHeading } from '@18f/identity-components';
import { Cancel } from '@18f/identity-verify-flow';
import HybridDocCaptureWarning from './hybrid-doc-capture-warning';
import DocumentSideAcuantCapture from './document-side-acuant-capture';
import DeviceContext from '../context/device';
import UploadContext from '../context/upload';
import TipList from './tip-list';
import DocumentCaptureNotReady from './document-capture-not-ready';
import { FeatureFlagContext } from '../context';
import DocumentCaptureAbandon from './document-capture-abandon';

/**
 * @typedef {'front'|'back'|'selfie'} DocumentSide
 */

/**
 * @typedef DocumentsStepValue
 *
 * @prop {Blob|string|null|undefined} front Front image value.
 * @prop {Blob|string|null|undefined} back Back image value.
 * @prop {Blob|string|null|undefined} selfie Selfie image value.
 * @prop {string=} front_image_metadata Front image metadata.
 * @prop {string=} back_image_metadata Back image metadata.
 */

/**
 * Sides of the ID document to present as file input.
 *
 * @type {DocumentSide[]}
 */
const DOCUMENT_SIDES = ['front', 'back'];

/**
 * @param {import('@18f/identity-form-steps').FormStepComponentProps<DocumentsStepValue>} props Props object.
 */
function DocumentsStep({
  value = {},
  onChange = () => {},
  errors = [],
  onError = () => {},
  registerField = () => undefined,
}) {
  const { t } = useI18n();
  const { isMobile } = useContext(DeviceContext);
  const { isLastStep } = useContext(FormStepsContext);
  const { flowPath } = useContext(UploadContext);
  const { notReadySectionEnabled, exitQuestionSectionEnabled, selfieCaptureEnabled } =
    useContext(FeatureFlagContext);

  const pageHeaderText = selfieCaptureEnabled
    ? t('doc_auth.headings.document_capture_with_selfie')
    : t('doc_auth.headings.document_capture');

  const defaultSideProps = {
    registerField,
    onChange,
    errors,
    onError,
  };
  return (
    <>
      {flowPath === 'hybrid' && <HybridDocCaptureWarning className="margin-bottom-4" />}
      <PageHeading>{pageHeaderText}</PageHeading>
      <h2>
        {selfieCaptureEnabled && '1. '}
        {t('doc_auth.headings.document_capture_subheader_id')}
      </h2>
      <TipList
        titleClassName="margin-bottom-0 text-bold"
        title={t('doc_auth.tips.document_capture_selfie_id_header_text')}
        items={[
          t('doc_auth.tips.document_capture_id_text1'),
          t('doc_auth.tips.document_capture_id_text2'),
          t('doc_auth.tips.document_capture_id_text3'),
        ].concat(!isMobile ? [t('doc_auth.tips.document_capture_id_text4')] : [])}
      />
      {DOCUMENT_SIDES.map((side) => (
        <DocumentSideAcuantCapture
          {...defaultSideProps}
          key={side}
          side={side}
          value={value[side]}
        />
      ))}
      {selfieCaptureEnabled && (
        <>
          <hr className="margin-y-5" />
          <h2>2. {t('doc_auth.headings.document_capture_subheader_selfie')}</h2>
          <DocumentSideAcuantCapture
            {...defaultSideProps}
            key="selfie"
            side="selfie"
            value={value.selfie}
          />
        </>
      )}
      {isLastStep ? <FormStepsButton.Submit /> : <FormStepsButton.Continue />}
      {notReadySectionEnabled && <DocumentCaptureNotReady />}
      {exitQuestionSectionEnabled && <DocumentCaptureAbandon />}
      <Cancel />
    </>
  );
}

export default DocumentsStep;
