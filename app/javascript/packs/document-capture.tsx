import { render } from 'react-dom';
import {
  DocumentCapture,
  DeviceContext,
  AcuantContextProvider,
  UploadContextProvider,
  ServiceProviderContextProvider,
  AnalyticsContextProvider,
  FailedCaptureAttemptsContextProvider,
  MarketingSiteContextProvider,
  InPersonContext,
  SelfieCaptureContext,
  PassportCaptureContext,
} from '@18f/identity-document-capture';
import { isCameraCapableMobile } from '@18f/identity-device';
import { FlowContext } from '@18f/identity-verify-flow';
import { trackEvent as baseTrackEvent } from '@18f/identity-analytics';
import { extendSession } from '@18f/identity-session';
import type { FlowPath, DeviceContextValue } from '@18f/identity-document-capture';

/**
 * @see MarketingSiteContextProvider
 * @see FailedCaptureAttemptsContext
 * @see UploadContext
 */
interface AppRootData {
  helpCenterRedirectUrl: string;
  maxAttemptsBeforeNativeCamera: string;
  acuantSdkUpgradeABTestingEnabled: string;
  useAlternateSdk: string;
  acuantVersion: string;
  flowPath: FlowPath;
  idType: string;
  cancelUrl: string;
  idvInPersonUrl?: string;
  optedInToInPersonProofing: string;
  securityAndPrivacyHowItWorksUrl: string;
  skipDocAuthFromHowToVerify: string;
  skipDocAuthFromHandoff: string;
  skipDocAuthFromSocure: string;
  howToVerifyURL: string;
  socureErrorsTimeoutURL: string;
  previousStepUrl: string;
  docAuthPassportsEnabled: string;
  docAuthSelfieDesktopTestMode: string;
  docAuthUploadEnabled: string;
  accountUrl: string;
  locationsUrl: string;
  sessionsUrl: string;
}

const appRoot = document.getElementById('document-capture-form')!;
const isMockClient = appRoot.hasAttribute('data-mock-client');
const glareThreshold = Number(appRoot.getAttribute('data-glare-threshold')) ?? undefined;
const sharpnessThreshold = Number(appRoot.getAttribute('data-sharpness-threshold')) ?? undefined;

function getServiceProvider() {
  const { spName: name = null, failureToProofUrl: failureToProofURL = '' } = appRoot.dataset;

  return { name, failureToProofURL };
}

function getSelfieCaptureEnabled() {
  const { docAuthSelfieCapture } = appRoot.dataset;
  return docAuthSelfieCapture === 'true';
}

function getUploadEnabled() {
  const { docAuthUploadEnabled } = appRoot.dataset;
  return docAuthUploadEnabled === 'true';
}

function getMetaContent(name): string | null {
  const meta = document.querySelector<HTMLMetaElement>(`meta[name="${name}"]`);
  return meta?.content ?? null;
}

const device: DeviceContextValue = { isMobile: isCameraCapableMobile() };

const trackEvent: typeof baseTrackEvent = (event, payload) => {
  const {
    idType,
    flowPath,
    acuantSdkUpgradeABTestingEnabled,
    useAlternateSdk,
    acuantVersion,
    optedInToInPersonProofing,
  } = appRoot.dataset;
  return baseTrackEvent(event, {
    ...payload,
    id_type: idType,
    flow_path: flowPath,
    acuant_sdk_upgrade_a_b_testing_enabled: acuantSdkUpgradeABTestingEnabled,
    use_alternate_sdk: useAlternateSdk,
    acuant_version: acuantVersion,
    opted_in_to_in_person_proofing: optedInToInPersonProofing === 'true',
  });
};

const formData: Record<string, any> = {
  document_capture_session_uuid: appRoot.getAttribute('data-document-capture-session-uuid'),
  locale: document.documentElement.lang,
};

const {
  helpCenterRedirectUrl: helpCenterRedirectURL,
  maxCaptureAttemptsBeforeNativeCamera,
  maxSubmissionAttemptsBeforeNativeCamera,
  acuantVersion,
  flowPath,
  idType,
  cancelUrl: cancelURL,
  accountUrl: accountURL,
  idvInPersonUrl: inPersonURL,
  securityAndPrivacyHowItWorksUrl: securityAndPrivacyHowItWorksURL,
  inPersonOutageMessageEnabled,
  inPersonOutageExpectedUpdateDate,
  optedInToInPersonProofing,
  usStatesTerritories = '',
  skipDocAuthFromHowToVerify,
  skipDocAuthFromHandoff,
  skipDocAuthFromSocure,
  howToVerifyUrl,
  socureErrorsTimeoutUrl,
  previousStepUrl,
  docAuthPassportsEnabled,
  docAuthSelfieDesktopTestMode,
  locationsUrl: locationsURL,
  sessionsUrl: sessionsURL,
} = appRoot.dataset as DOMStringMap & AppRootData;

let parsedUsStatesTerritories = [];
try {
  parsedUsStatesTerritories = JSON.parse(usStatesTerritories);
} catch (e) {}

render(
  <MarketingSiteContextProvider
    helpCenterRedirectURL={helpCenterRedirectURL}
    securityAndPrivacyHowItWorksURL={securityAndPrivacyHowItWorksURL}
  >
    <DeviceContext.Provider value={device}>
      <InPersonContext.Provider
        value={{
          inPersonURL,
          locationsURL,
          inPersonOutageExpectedUpdateDate,
          inPersonOutageMessageEnabled: inPersonOutageMessageEnabled === 'true',
          optedInToInPersonProofing: optedInToInPersonProofing === 'true',
          usStatesTerritories: parsedUsStatesTerritories,
          skipDocAuthFromHowToVerify: skipDocAuthFromHowToVerify === 'true',
          skipDocAuthFromHandoff: skipDocAuthFromHandoff === 'true',
          skipDocAuthFromSocure: skipDocAuthFromSocure === 'true',
          howToVerifyURL: howToVerifyUrl,
          socureErrorsTimeoutURL: socureErrorsTimeoutUrl,
          passportEnabled: String(docAuthPassportsEnabled) === 'true',
          previousStepURL: previousStepUrl,
        }}
      >
        <AnalyticsContextProvider trackEvent={trackEvent}>
          <AcuantContextProvider
            sdkSrc={acuantVersion && `/acuant/${acuantVersion}/AcuantJavascriptWebSdk.min.js`}
            cameraSrc={acuantVersion && `/acuant/${acuantVersion}/AcuantCamera.min.js`}
            passiveLivenessOpenCVSrc={acuantVersion && `/acuant/${acuantVersion}/opencv.min.js`}
            passiveLivenessSrc={
              getSelfieCaptureEnabled()
                ? acuantVersion && `/acuant/${acuantVersion}/AcuantPassiveLiveness.min.js`
                : undefined
            }
            credentials={getMetaContent('acuant-sdk-initialization-creds')}
            endpoint={getMetaContent('acuant-sdk-initialization-endpoint')}
            glareThreshold={glareThreshold}
            sharpnessThreshold={sharpnessThreshold}
          >
            <UploadContextProvider
              endpoint={String(appRoot.getAttribute('data-endpoint'))}
              statusEndpoint={String(appRoot.getAttribute('data-status-endpoint'))}
              statusPollInterval={Number(appRoot.getAttribute('data-status-poll-interval-ms'))}
              isMockClient={isMockClient}
              isUploadEnabled={getUploadEnabled()}
              formData={formData}
              flowPath={flowPath}
              idType={idType}
            >
              <FlowContext.Provider
                value={{
                  accountURL,
                  cancelURL,
                  currentStep: 'document_capture',
                }}
              >
                <ServiceProviderContextProvider value={getServiceProvider()}>
                  <SelfieCaptureContext.Provider
                    value={{
                      isSelfieCaptureEnabled: getSelfieCaptureEnabled(),
                      isSelfieDesktopTestMode: String(docAuthSelfieDesktopTestMode) === 'true',
                      showHelpInitially: true,
                    }}
                  >
                    <PassportCaptureContext.Provider value={{ showHelpInitially: true }}>
                      <FailedCaptureAttemptsContextProvider
                        maxCaptureAttemptsBeforeNativeCamera={Number(
                          maxCaptureAttemptsBeforeNativeCamera,
                        )}
                        maxSubmissionAttemptsBeforeNativeCamera={Number(
                          maxSubmissionAttemptsBeforeNativeCamera,
                        )}
                        failedFingerprints={{ front: [], back: [], passport: [] }}
                      >
                        <DocumentCapture onStepChange={() => extendSession(sessionsURL)} />
                      </FailedCaptureAttemptsContextProvider>
                    </PassportCaptureContext.Provider>
                  </SelfieCaptureContext.Provider>
                </ServiceProviderContextProvider>
              </FlowContext.Provider>
            </UploadContextProvider>
          </AcuantContextProvider>
        </AnalyticsContextProvider>
      </InPersonContext.Provider>
    </DeviceContext.Provider>
  </MarketingSiteContextProvider>,
  appRoot,
);
