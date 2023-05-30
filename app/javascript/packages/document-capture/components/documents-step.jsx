import { useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { FormStepsButton, FormStepsContext } from '@18f/identity-form-steps';
import { PageHeading } from '@18f/identity-components';
import { Cancel } from '@18f/identity-verify-flow';
import HybridDocCaptureWarning from './hybrid-doc-capture-warning';
import DocumentSideAcuantCapture from './document-side-acuant-capture';
import DeviceContext from '../context/device';
import UploadContext from '../context/upload';
import CaptureTroubleshooting from './capture-troubleshooting';
import DocumentCaptureTroubleshootingOptions from './document-capture-troubleshooting-options';

/**
 * @typedef {'front'|'back'} DocumentSide
 */

/**
 * @typedef DocumentsStepValue
 *
 * @prop {Blob|string|null|undefined} front Front image value.
 * @prop {Blob|string|null|undefined} back Back image value.
 * @prop {string=} front_image_metadata Front image metadata.
 * @prop {string=} back_image_metadata Back image metadata.
 */

/**
 * Sides of document to present as file input.
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

  return (
    <CaptureTroubleshooting>
      {flowPath === 'hybrid' && <HybridDocCaptureWarning className="margin-bottom-4" />}
      <PageHeading>{t('doc_auth.headings.document_capture')}</PageHeading>
      <p>{t('doc_auth.info.document_capture_intro_acknowledgment')}</p>
      <p className="margin-bottom-0">{t('doc_auth.tips.document_capture_header_text')}</p>
      <ul>
        <li>{t('doc_auth.tips.document_capture_id_text1')}</li>
        <li>{t('doc_auth.tips.document_capture_id_text2')}</li>
        <li>{t('doc_auth.tips.document_capture_id_text3')}</li>
        {!isMobile && <li>{t('doc_auth.tips.document_capture_id_text4')}</li>}
      </ul>
      {DOCUMENT_SIDES.map((side) => (
        <DocumentSideAcuantCapture
          key={side}
          side={side}
          registerField={registerField}
          value={value[side]}
          onChange={onChange}
          errors={errors}
          onError={onError}
        />
      ))}
      {isLastStep ? <FormStepsButton.Submit /> : <FormStepsButton.Continue />}
      <DocumentCaptureTroubleshootingOptions />
      <Cancel />
    </CaptureTroubleshooting>
  );
}

export default DocumentsStep;
