import { useContext } from 'react';
import { TroubleshootingOptions } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
import type { TroubleshootingOption } from '@18f/identity-components/troubleshooting-options';
import ServiceProviderContext from '../context/service-provider';
import HelpCenterContext from '../context/help-center';

interface InPersonTroubleshootingOptionsProps {
  /**
   * Custom heading to show in place of default.
   */
  heading?: string;

  /**
   * Location parameter to append to links.
   */
  location?: string;
}

function InPersonTroubleshootingOptions({
  heading,
  location = 'in_person_troubleshooting_options',
}: InPersonTroubleshootingOptionsProps) {
  const { t } = useI18n();
  const { getHelpCenterURL } = useContext(HelpCenterContext);
  const { name: spName, getFailureToProofURL } = useContext(ServiceProviderContext);

  return (
    <TroubleshootingOptions
      heading={heading}
      options={
        [
          {
            url: getHelpCenterURL({
              category: 'verify-your-identity',
              article: 'how-to-verify-in-person',
              location,
            }),
            text: t('idv.troubleshooting.options.learn_more_verify_in_person'),
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
  );
}

export default InPersonTroubleshootingOptions;
