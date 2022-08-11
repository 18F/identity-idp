import { TroubleshootingOptions } from '@18f/identity-components';
import { getConfigValue } from '@18f/identity-config';
import { t } from '@18f/identity-i18n';

function VerifyFlowTroubleshootingOptions() {
  return (
    <TroubleshootingOptions
      heading={t('components.troubleshooting_options.default_heading')}
      options={[
        {
          url: 'https://login.gov/contact/',
          text: t('idv.troubleshooting.options.contact_support', {
            app_name: getConfigValue('appName'),
          }),
          isExternal: true,
        },
      ]}
    />
  );
}

export default VerifyFlowTroubleshootingOptions;
