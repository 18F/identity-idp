import { useContext } from 'react';
import DeviceContext from '../context/device';
import useI18n from '../hooks/use-i18n';

/**
 * Renders a document usage disclosure for desktop devices only. On mobile devices, an equivalent
 * message is displayed on the introductory step.
 *
 * @type {import('react').FC}
 */
function DesktopDocumentDisclosure() {
  const { isMobile } = useContext(DeviceContext);
  const { t } = useI18n();

  return isMobile ? null : <p>{t('doc_auth.info.document_capture_upload_image')}</p>;
}

export default DesktopDocumentDisclosure;
