import { useContext } from 'react';
import { TroubleshootingOptions } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
import ServiceProviderContext from '../context/service-provider';
import MarketingSiteContext from '../context/marketing-site';

/** @typedef {import('@18f/identity-components/troubleshooting-options').TroubleshootingOption} TroubleshootingOption */

function DocumentCaptureTroubleshootingOptions() {
  const { t } = useI18n();
  const { documentCaptureTipsURL, supportedDocumentsURL } = useContext(MarketingSiteContext);
  const { name: spName, getFailureToProofURL } = useContext(ServiceProviderContext);

  return (
    <TroubleshootingOptions
      heading={t('idv.troubleshooting.headings.having_trouble')}
      options={
        /** @type {TroubleshootingOption[]} */ ([
          documentCaptureTipsURL && {
            url: documentCaptureTipsURL,
            text: t('idv.troubleshooting.options.doc_capture_tips'),
            isExternal: true,
          },
          supportedDocumentsURL && {
            url: supportedDocumentsURL,
            text: t('idv.troubleshooting.options.supported_documents'),
            isExternal: true,
          },
          spName && {
            url: getFailureToProofURL('document_capture_troubleshooting_options'),
            text: t('idv.troubleshooting.options.get_help_at_sp', { sp_name: spName }),
            isExternal: true,
          },
        ].filter(Boolean))
      }
    />
  );
}

export default DocumentCaptureTroubleshootingOptions;
