import { useContext } from 'react';
import { TroubleshootingOptions } from '@18f/identity-components';
import { getConfigValue } from '@18f/identity-config';
import { t } from '@18f/identity-i18n';
import FlowContext from './context/flow-context';

function VerifyFlowTroubleshootingOptions() {
  const { inPersonURL } = useContext(FlowContext);

  return (
    <>
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
      {inPersonURL && (
        <TroubleshootingOptions
          isNewFeatures
          heading={t('idv.troubleshooting.headings.are_you_near')}
          options={[
            {
              url: inPersonURL,
              text: t('idv.troubleshooting.options.verify_in_person'),
            },
          ]}
        />
      )}
    </>
  );
}

export default VerifyFlowTroubleshootingOptions;
