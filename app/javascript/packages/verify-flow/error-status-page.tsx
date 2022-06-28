import { Button, Link, StatusPage } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import { formatHTML } from '@18f/identity-react-i18n';
import VerifyFlowTroubleshootingOptions from './verify-flow-troubleshooting-options';

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
      troubleshootingOptions={<VerifyFlowTroubleshootingOptions />}
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
