import { t } from '@18f/identity-i18n';
import { Alert } from '@18f/identity-components';
import { useContext } from 'react';
import { getConfigValue } from '@18f/identity-config';
import { InPersonContext } from '../context';

function InPersonOutageAlert() {
  const { inPersonOutageExpectedUpdateDate } = useContext(InPersonContext);

  return (
    <Alert type="warning" className="margin-bottom-4" textTag="div">
      <>
        <p className="margin-bottom-2">
          <strong>
            {t('idv.failure.exceptions.in_person_outage_error_message.post_cta.title', {
              day_of_week: new Intl.DateTimeFormat('en-US', { weekday: 'long' }).format(
                new Date(`${inPersonOutageExpectedUpdateDate}, ${new Date().getFullYear()}`),
              ),
              date: inPersonOutageExpectedUpdateDate,
            })}
          </strong>
        </p>
        <p>
          {t('idv.failure.exceptions.in_person_outage_error_message.post_cta.body', {
            app_name: getConfigValue('appName'),
          })}
        </p>
      </>
    </Alert>
  );
}

export default InPersonOutageAlert;
