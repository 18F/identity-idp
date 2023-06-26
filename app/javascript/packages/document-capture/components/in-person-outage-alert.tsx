import { t } from '@18f/identity-i18n';
import { Alert } from '@18f/identity-components';
import { getConfigValue } from '@18f/identity-config';

function InPersonOutageAlert() {
  return (
    <Alert type="warning" className="margin-bottom-4">
      <>
        <div className="margin-bottom-2">
          <strong>
            {t('idv.failure.exceptions.in_person_outage_error_message.post_cta.title', {
              day_of_week: 'random day',
              date: 'random date',
            })}
          </strong>
        </div>
        <div>
          {t('idv.failure.exceptions.in_person_outage_error_message.post_cta.body', {
            app_name: getConfigValue('appName'),
          })}
        </div>
      </>
    </Alert>
  );
}

export default InPersonOutageAlert;
