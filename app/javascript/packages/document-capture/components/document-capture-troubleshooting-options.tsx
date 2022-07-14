import { useContext } from 'react';
import { FlowContext } from '@18f/identity-verify-flow';
import { TroubleshootingOptions } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
import { removeUnloadProtection } from '@18f/identity-url';
import type { TroubleshootingOption } from '@18f/identity-components/troubleshooting-options';
import ServiceProviderContext from '../context/service-provider';
import HelpCenterContext from '../context/help-center';

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

  /**
   * If there are any errors (toggles whether or not to show in person proofing option)
   */
  hasErrors?: boolean;
}

function DocumentCaptureTroubleshootingOptions({
  heading,
  location = 'document_capture_troubleshooting_options',
  showDocumentTips = true,
  hasErrors,
}: DocumentCaptureTroubleshootingOptionsProps) {
  const { t } = useI18n();
  const { inPersonURL } = useContext(FlowContext);
  const { getHelpCenterURL } = useContext(HelpCenterContext);
  const { name: spName, getFailureToProofURL } = useContext(ServiceProviderContext);

  return (
    <>
      <TroubleshootingOptions
        heading={heading}
        options={
          [
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
                article: 'accepted-state-issued-identification',
                location,
              }),
              text: t('idv.troubleshooting.options.supported_documents'),
              isExternal: true,
            },
            spName && {
              url: getFailureToProofURL(location),
              text: t('idv.troubleshooting.options.get_help_at_sp', { sp_name: spName }),
              isExternal: true,
            },
          ].filter(Boolean) as TroubleshootingOption[]
        }
      />
      {hasErrors && inPersonURL && (
        <TroubleshootingOptions
          isNewFeatures
          heading={t('idv.troubleshooting.headings.are_you_near')}
          options={[
            {
              url: inPersonURL,
              text: t('idv.troubleshooting.options.verify_in_person'),
              onClick: removeUnloadProtection,
            },
          ]}
        />
      )}
    </>
  );
}

export default DocumentCaptureTroubleshootingOptions;
