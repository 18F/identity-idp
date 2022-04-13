import { useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { FormStepsContinueButton } from '@18f/identity-form-steps';
import DocumentSideAcuantCapture from './document-side-acuant-capture';
import DeviceContext from '../context/device';
import withBackgroundEncryptedUpload from '../higher-order/with-background-encrypted-upload';
import CaptureTroubleshooting from './capture-troubleshooting';
import DocumentCaptureTroubleshootingOptions from './document-capture-troubleshooting-options';
import PageHeading from './page-heading';
import StartOverOrCancel from './start-over-or-cancel';

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

  return (
    <CaptureTroubleshooting>
      <PageHeading>{t('doc_auth.headings.document_capture')}</PageHeading>
      {isMobile && <p>{t('doc_auth.info.document_capture_intro_acknowledgment')}</p>}
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
      <FormStepsContinueButton />
      <DocumentCaptureTroubleshootingOptions />
      <StartOverOrCancel />
    </CaptureTroubleshooting>
  );
}

export default withBackgroundEncryptedUpload(DocumentsStep);
