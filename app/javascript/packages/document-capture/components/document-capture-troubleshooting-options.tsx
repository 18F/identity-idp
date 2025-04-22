import { useContext } from 'react';
import { TroubleshootingOptions } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
import type { TroubleshootingOption } from '@18f/identity-components/troubleshooting-options';
import MarketingSiteContext from '../context/marketing-site';
import InPersonCallToAction from './in-person-call-to-action';
import { InPersonContext } from '../context';

interface DocumentCaptureTroubleshootingOptionsProps {
  /**
   * Custom heading to show in place of default.
   */
  heading?: string;

  /**
   * Location parameter to append to links.
   */
  location?: string;

  /**
   * Whether to include tips for taking a good photo.
   */
  showDocumentTips?: boolean;
}

function DocumentCaptureTroubleshootingOptions({
  heading,
  location = 'document_capture_troubleshooting_options',
  showDocumentTips = true,
}: DocumentCaptureTroubleshootingOptionsProps) {
  const { t } = useI18n();
  const { inPersonURL, passportEnabled } = useContext(InPersonContext);
  const { getHelpCenterURL } = useContext(MarketingSiteContext);

  return (
    <>
      {inPersonURL && <InPersonCallToAction />}
      <TroubleshootingOptions
        heading={heading}
        options={
          [
            passportEnabled && {
              url: 'choose_id_type',
              text: t('idv.troubleshooting.options.use_another_id_type'),
              isExternal: false,
            },
            showDocumentTips && {
              url: getHelpCenterURL({
                category: 'verify-your-identity',
                article: 'how-to-add-images-of-your-state-issued-id',
                location,
              }),
              text: t('idv.troubleshooting.options.doc_capture_tips'),
              isExternal: true,
            },
            showDocumentTips && {
              url: getHelpCenterURL({
                category: 'verify-your-identity',
                article: 'accepted-identification-documents',
                location,
              }),
              text: t('idv.troubleshooting.options.supported_documents'),
              isExternal: true,
            },
          ].filter(Boolean) as TroubleshootingOption[]
        }
      />
    </>
  );
}

export default DocumentCaptureTroubleshootingOptions;
