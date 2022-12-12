import { useContext, ReactNode } from 'react';
import { useI18n, formatHTML } from '@18f/identity-react-i18n';
import ServiceProviderContext from '../context/service-provider';
import { getConfigValue } from '@18f/identity-config';

function formatWithStrong(text: string): ReactNode {
  return formatHTML(text, {
    strong: ({ children }) => <strong>{children}</strong>,
  });
}

function HybridDocCaptureWarning() {
  const { t } = useI18n();
  // Determine the Service Provider name to display,
  // in some circumstances.
  // If there is no SP, we default to the appName
  const spContext = useContext(ServiceProviderContext);
  const serviceProviderName = spContext.name;
  const appName = getConfigValue('appName');

  const listHeadingText = t('doc_auth.hybrid_flow_warning.only_add_if_text');
  const ownAccountItemText = t('doc_auth.hybrid_flow_warning.only_add_own_account_html', {
    app_name: appName,
  });
  const phoneVerifyItemText = t('doc_auth.hybrid_flow_warning.only_add_phone_verify_html', {
    app_name: appName,
  });
  let spServicesItemText;
  let warningText = t('doc_auth.hybrid_flow_warning.explanation_non_sp_html', {
    app_name: appName,
  });
  if (serviceProviderName) {
    warningText = t('doc_auth.hybrid_flow_warning.explanation_html', {
      app_name: appName,
      service_provider_name: serviceProviderName,
    });
    spServicesItemText = t('doc_auth.hybrid_flow_warning.only_add_sp_services_html', {
      service_provider_name: serviceProviderName,
    });
  }

  return (
    <div className="usa-alert usa-alert--warning" role="status">
      <div className="usa-alert__body">
        <p>{formatWithStrong(warningText)}</p>
        <br />
        <p className="usa-alert__text">
          <b>{listHeadingText}</b>
        </p>
        <br />
        <ul>
          <li>{ownAccountItemText}</li>
          <li>{formatWithStrong(phoneVerifyItemText)}</li>
          {serviceProviderName && <li>{formatWithStrong(spServicesItemText)}</li>}
        </ul>
      </div>
    </div>
  );
}

export default HybridDocCaptureWarning;
