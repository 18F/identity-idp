import { useI18n, formatHTML } from '@18f/identity-react-i18n';

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
    '%{app_name}',
    appName,
  );
  const phoneVerifyItemText = t('doc_auth.hybrid_flow_warning.only_add_phone_verify_html').replace(
    '%{app_name}',
    appName,
  );
  let spServicesItemText;
  let warningText = t('doc_auth.hybrid_flow_warning.explanation_non_sp_html').replace(
    '%{app_name}',
    appName,
  );
  if (serviceProviderName) {
    warningText = t('doc_auth.hybrid_flow_warning.explanation_html')
      .replace('%{app_name}', appName)
      .replace('%{service_provider_name}', serviceProviderName);
    spServicesItemText = t('doc_auth.hybrid_flow_warning.only_add_sp_services_html').replace(
      '%{service_provider_name}',
      serviceProviderName,
    );
  }

  return (
    <div className="usa-alert usa-alert--warning" role="status">
      <div className="usa-alert__body">
        <p>
          {formatHTML(warningText, {
            b: ({ children }) => <b>{children}</b>,
          })}
        </p>
        <br />
        <p className="usa-alert__text">
          <b>{listHeadingText}</b>
        </p>
        <br />
        <ul>
          <li>{ownAccountItemText}</li>
          <li>
            {formatHTML(phoneVerifyItemText, {
              b: ({ children }) => <b>{children}</b>,
            })}
          </li>
          {serviceProviderName && (
            <li>
              {formatHTML(spServicesItemText, {
                b: ({ children }) => <b>{children}</b>,
              })}
            </li>
          )}
        </ul>
      </div>
    </div>
  );
}

export default HybridDocCaptureWarning;
