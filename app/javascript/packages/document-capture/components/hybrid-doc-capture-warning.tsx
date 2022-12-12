import { useI18n } from '@18f/identity-react-i18n';

type HybridDocCaptureWarningProps = {
  appName: string;
  serviceProviderName: string | null;
};

function HybridDocCaptureWarning({
  appName = 'Login.gov',
  serviceProviderName = null,
}: HybridDocCaptureWarningProps) {
  const { t } = useI18n();

  const listHeadingText = t('doc_auth.hybrid_flow_warning.only_add_if_text');
  const ownAccountItemText = t('doc_auth.hybrid_flow_warning.only_add_own_account_html').replace(
    '%{appName}',
    appName,
  );
  const phoneVerifyItemText = t('doc_auth.hybrid_flow_warning.only_add_phone_verify_html').replace(
    '%{appName}',
    appName,
  );
  let spServicesItemText;
  let warningText = t('doc_auth.hybrid_flow_warning.explanation_non_sp_html').replace(
    '%{appName}',
    appName,
  );
  if (serviceProviderName) {
    warningText = t('doc_auth.hybrid_flow_warning.explanation_html')
      .replace('%{appName}', appName)
      .replace('%{serviceProviderName}', serviceProviderName);
    spServicesItemText = t('doc_auth.hybrid_flow_warning.only_add_sp_services_html').replace(
      '%{serviceProviderName}',
      serviceProviderName,
    );
  }

  return (
    <div className="usa-alert usa-alert--warning" role="status">
      <div className="usa-alert__body">
        <p
          className="usa-alert__text"
          dangerouslySetInnerHTML={{
            __html: warningText,
          }}
        />
        <br />
        <p className="usa-alert__text">
          <b>{listHeadingText}</b>
        </p>
        <br />
        <ul>
          <li>{ownAccountItemText}</li>
          <li
            dangerouslySetInnerHTML={{
              __html: phoneVerifyItemText,
            }}
          />
          {serviceProviderName && (
            <li
              dangerouslySetInnerHTML={{
                __html: spServicesItemText,
              }}
            />
          )}
        </ul>
      </div>
    </div>
  );
}

export default HybridDocCaptureWarning;
