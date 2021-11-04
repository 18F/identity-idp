import { useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { BlockLink } from '@18f/identity-components';
import { FormStepsContinueButton } from './form-steps';
import DocumentSideAcuantCapture from './document-side-acuant-capture';
import DeviceContext from '../context/device';
import ServiceProviderContext from '../context/service-provider';
import withBackgroundEncryptedUpload from '../higher-order/with-background-encrypted-upload';
import DesktopDocumentDisclosure from './desktop-document-disclosure';
import CaptureTroubleshooting from './capture-troubleshooting';
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
 * @return {Boolean} whether or not the value is valid for the document step
 */
function documentsStepValidator(value = {}) {
  return DOCUMENT_SIDES.every((side) => !!value[side]);
}

/**
 * @param {import('./form-steps').FormStepComponentProps<DocumentsStepValue>} props Props object.
 */
function DocumentsStep({
  value = {},
  onChange = () => {},
  errors = [],
  onError = () => {},
  registerField = () => undefined,
}) {
  const { t, formatHTML } = useI18n();
  const { isMobile } = useContext(DeviceContext);
  const serviceProvider = useContext(ServiceProviderContext);

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
      {serviceProvider.name && (
        <BlockLink url={serviceProvider.getFailureToProofURL('documents_having_trouble')} isNewTab>
          {formatHTML(t('doc_auth.info.get_help_at_sp_html', { sp_name: serviceProvider.name }), {
            strong: 'strong',
          })}
        </BlockLink>
      )}
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
      <DesktopDocumentDisclosure />
      <StartOverOrCancel />
    </CaptureTroubleshooting>
  );
}

export default withBackgroundEncryptedUpload(DocumentsStep);

export { documentsStepValidator };
