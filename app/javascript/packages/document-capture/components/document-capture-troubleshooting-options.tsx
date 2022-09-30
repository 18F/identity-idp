import { useContext } from 'react';
import { FlowContext } from '@18f/identity-verify-flow';
import { TroubleshootingOptions } from '@18f/identity-components';
import { useI18n, formatHTML } from '@18f/identity-react-i18n';
import type { TroubleshootingOption } from '@18f/identity-components/troubleshooting-options';
import ServiceProviderContext from '../context/service-provider';
import MarketingSiteContext from '../context/marketing-site';
import AnalyticsContext from '../context/analytics';
import { nonBreaking } from '../higher-order/with-background-encrypted-upload';

/**
 * Returns an internationalized list with appropriately placed non-breaking spaces
 *
 * @param {list} string Original string.
 *
 * @return String with non-breaking spaces.
 */
const toI18nList = (list) => {
  const nonBreakingListItems = list.map(nonBreaking);
  const i18nList = new Intl.ListFormat('en', { type: 'disjunction', style: 'short' });

  return i18nList.format(nonBreakingListItems);
};

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
   * Whether to include option to verify in person.
   */
  showInPersonOption?: boolean;

  /**
   * If there are any errors (toggles whether or not to show in person proofing option)
   */
  hasErrors?: boolean;
}

function DocumentCaptureTroubleshootingOptions({
  heading,
  location = 'document_capture_troubleshooting_options',
  showDocumentTips = true,
  showInPersonOption = true,
  hasErrors,
}: DocumentCaptureTroubleshootingOptionsProps) {
  const { t } = useI18n();
  const { inPersonURL } = useContext(FlowContext);
  const { getHelpCenterURL } = useContext(MarketingSiteContext);
  const { trackEvent } = useContext(AnalyticsContext);
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
      {hasErrors && inPersonURL && showInPersonOption && (
        <TroubleshootingOptions
          isNewFeatures
          heading={formatHTML(
            t('idv.troubleshooting.headings.are_you_near', {
              pilot_locations: toI18nList(t(['in_person_proofing.pilot_locations'])),
            }),
            { wbr: 'wbr' },
          )}
          options={[
            {
              url: '#location',
              text: t('idv.troubleshooting.options.verify_in_person'),
              onClick: () => trackEvent('IdV: verify in person troubleshooting option clicked'),
            },
          ]}
        />
      )}
    </>
  );
}

export default DocumentCaptureTroubleshootingOptions;
