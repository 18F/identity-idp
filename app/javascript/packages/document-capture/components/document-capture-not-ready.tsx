import { Button } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
import { useContext } from 'react';
import FlowContext from '@18f/identity-verify-flow/context/flow-context';
import { addSearchParams, forceRedirect, Navigate } from '@18f/identity-url';
import { getConfigValue } from '@18f/identity-config';
import AnalyticsContext from '../context/analytics';
import { ServiceProviderContext } from '../context';

export interface DocumentCaptureNotReadyProps {
  navigate?: Navigate;
}

function DocumentCaptureNotReady({ navigate }: DocumentCaptureNotReadyProps) {
  const { t } = useI18n();
  const { trackEvent } = useContext(AnalyticsContext);
  const { currentStep } = useContext(FlowContext);
  const { name: spName, failureToProofURL } = useContext(ServiceProviderContext);
  const appName = getConfigValue('appName');
  const header = <h2 className="h3">{t('doc_auth.not_ready.header')}</h2>;

  const content = (
    <p>
      {spName
        ? t('doc_auth.not_ready.content_sp', {
            sp_name: spName,
            app_name: appName,
          })
        : t('doc_auth.not_ready.content_nosp', {
            app_name: appName,
          })}
    </p>
  );
  const handleExit = () => {
    trackEvent('IdV: docauth not ready link clicked');
    forceRedirect(
      addSearchParams(spName ? failureToProofURL : '/account', {
        step: currentStep,
        location: 'not_ready',
      }),
      navigate,
    );
  };

  return (
    <>
      {header}
      {content}

      <Button isUnstyled className="margin-top-1" onClick={handleExit}>
        {spName
          ? t('doc_auth.not_ready.button_sp', { app_name: appName, sp_name: spName })
          : t('doc_auth.not_ready.button_nosp')}
      </Button>
    </>
  );
}

export default DocumentCaptureNotReady;
