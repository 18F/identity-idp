import { useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import DeviceContext from '../context/device';

/**
 * Renders a document usage disclosure for desktop devices only. On mobile devices, an equivalent
 * message in the introduction.
 *
 * @type {import('react').FC}
 */
function DesktopDocumentDisclosure() {
  const { isMobile } = useContext(DeviceContext);
  const { t } = useI18n();

  return isMobile ? null : <p>{t('doc_auth.info.document_capture_upload_image')}</p>;
}

export default DesktopDocumentDisclosure;
