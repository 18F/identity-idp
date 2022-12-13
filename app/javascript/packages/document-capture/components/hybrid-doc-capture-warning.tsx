import { useContext, forwardRef } from 'react';
import type { ReactNode, ForwardedRef } from 'react';
import { useI18n, formatHTML } from '@18f/identity-react-i18n';
import { getConfigValue } from '@18f/identity-config';
import { Alert } from '@18f/identity-components';
import ServiceProviderContext from '../context/service-provider';

function formatWithStrong(text: string): ReactNode {
  return formatHTML(text, {
    strong: ({ children }) => <strong>{children}</strong>,
  });
}

interface HybridDocCaptureWarningProps {
  /**
   * A class string to append to root element
   */
  className?: string;
}

function HybridDocCaptureWarning(
  { className = '' }: HybridDocCaptureWarningProps,
  ref: ForwardedRef<any>,
): JSX.Element {
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
    <Alert textTag="div" className={className} ref={ref}>
      <p className="margin-bottom-4">{formatWithStrong(warningText)}</p>
      <p className="margin-bottom-4">
        <strong>{listHeadingText}</strong>
      </p>
      <ul>
        <li>{ownAccountItemText}</li>
        <li>{formatWithStrong(phoneVerifyItemText)}</li>
        {serviceProviderName && <li>{formatWithStrong(spServicesItemText)}</li>}
      </ul>
    </Alert>
  );
}

export default forwardRef(HybridDocCaptureWarning);
