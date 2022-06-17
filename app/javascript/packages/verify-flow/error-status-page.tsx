import { Button, Link, StatusPage, TroubleshootingOptions } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import { formatHTML } from '@18f/identity-react-i18n';
import { getConfigValue } from '@18f/identity-config';

function ErrorStatusPage() {
  return (
    <StatusPage
      status="warning"
      header={t('idv.failure.sessions.exception')}
      actionButtons={[
        <Button key="try_again" href={window.location.href} isBig isWide>
          {t('idv.failure.button.warning')}
        </Button>,
      ]}
      troubleshootingOptions={
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
      }
    >
      <p>
        {formatHTML(t('idv.failure.exceptions.text_html', { link: `<a></a>` }), {
          a() {
            return (
              <Link href="https://login.gov/contact/" isExternal={false}>
                {t('idv.failure.exceptions.link')}
              </Link>
            );
          },
        })}
      </p>
    </StatusPage>
  );
}

export default ErrorStatusPage;
