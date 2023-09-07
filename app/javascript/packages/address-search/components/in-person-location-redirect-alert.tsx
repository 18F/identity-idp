import { Alert } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import { getConfigValue } from '@18f/identity-config';

interface InPersonLocationRedirectAlertProps {
  infoAlertURL?: string;
}

function InPersonLocationRedirectAlert({
  infoAlertURL = 'https://login.gov/',
}: InPersonLocationRedirectAlertProps) {
  const infoAlertText = t('in_person_proofing.body.location.po_search.you_must_start.message', {
    app_name: getConfigValue('appName'),
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
