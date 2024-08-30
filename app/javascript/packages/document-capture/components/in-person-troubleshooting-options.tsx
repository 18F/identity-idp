import { useContext } from 'react';
import { TroubleshootingOptions } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
import type { TroubleshootingOption } from '@18f/identity-components/troubleshooting-options';
import MarketingSiteContext from '../context/marketing-site';

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
  const { getHelpCenterURL } = useContext(MarketingSiteContext);

  return (
    <TroubleshootingOptions
      heading={heading}
      options={
        [
          {
            url: getHelpCenterURL({
              category: 'verify-your-identity',
              article: 'verify-your-identity-in-person',
              location,
            }),
            text: t('idv.troubleshooting.options.learn_more_verify_in_person'),
            isExternal: true,
          },
          {
            url: getHelpCenterURL({
              category: 'verify-your-identity',
              article: 'phone-number',
              location,
            }),
            text: t('idv.troubleshooting.options.learn_more_verify_by_phone_in_person'),
            isExternal: true,
          },
        ].filter(Boolean) as TroubleshootingOption[]
      }
    />
  );
}

export default InPersonTroubleshootingOptions;
