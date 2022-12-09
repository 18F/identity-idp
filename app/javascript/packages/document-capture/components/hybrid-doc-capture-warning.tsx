import { Alert } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';

type HybridDocCaptureWarningProps = {
  appName: string;
  serviceProviderName: string | null;
};

function HybridDocCaptureWarning({
  appName = 'Login.gov',
  serviceProviderName = null,
}: HybridDocCaptureWarningProps) {
  const nameToDisplay = serviceProviderName ? serviceProviderName : appName;
  const { t } = useI18n();
  return (
    <div className="usa-alert usa-alert--warning" role="status">
      <div className="usa-alert__body">
        <p
          className="usa-alert__text"
          dangerouslySetInnerHTML={{
            __html: t('doc_auth.hybrid_flow_warning.explanation_html')
              .replace('%{appName}', appName)
              .replace('%{serviceProviderName}', nameToDisplay),
          }}
        ></p>
        <br />
        <p className="usa-alert__text">
          <b>{t('doc_auth.hybrid_flow_warning.only_add_if_text')}</b>
        </p>
        <br />
        <ul>
          <li>
            {t('doc_auth.hybrid_flow_warning.only_add_own_account_html').replace(
              '%{appName}',
              appName,
            )}
          </li>
          <li
            dangerouslySetInnerHTML={{
              __html: t('doc_auth.hybrid_flow_warning.only_add_phone_verify_html').replace(
                '%{appName}',
                appName,
              ),
            }}
          ></li>
          <li
            dangerouslySetInnerHTML={{
              __html: t('doc_auth.hybrid_flow_warning.only_add_sp_services_html').replace(
                '%{serviceProviderName}',
                nameToDisplay,
              ),
            }}
          ></li>
        </ul>
      </div>
    </div>
  );
}

export default HybridDocCaptureWarning;
