import { Alert } from '@18f/identity-components';
import { useContext } from 'react';
import { t } from '@18f/identity-i18n';
import { getConfigValue } from '@18f/identity-config';
import MarketingSiteContext from '../context/marketing-site';

function InPersonLocationRedirectAlert() {
  const { getHelpCenterURL } = useContext(MarketingSiteContext);

  const infoAlertText = t('in_person_proofing.body.location.po_search.you_must_start.message', {
    app_name: getConfigValue('appName'),
  });

  const infoAlertURL = getHelpCenterURL({
    category: 'verify-your-identity',
    article: 'verify-your-identity-in-person',
    location: 'in_person_troubleshooting_options',
  });

  return (
    <Alert type="info" className="margin-bottom-4">
      <strong>{infoAlertText}</strong>{' '}
      <a href={infoAlertURL}>
        {t('in_person_proofing.body.location.po_search.you_must_start.link_text')}
      </a>
    </Alert>
  );
}

export default InPersonLocationRedirectAlert;
