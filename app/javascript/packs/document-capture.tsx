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
  cancelUrl: string;
  idvInPersonUrl?: string;
  optedInToInPersonProofing: string;
  securityAndPrivacyHowItWorksUrl: string;
  skipDocAuthFromHowToVerify: string;
  skipDocAuthFromHandoff: string;
  howToVerifyURL: string;
  previousStepUrl: string;
  docAuthSelfieDesktopTestMode: string;
  accountUrl: string;
  locationsUrl: string;
  addressSearchUrl: string;
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

function getMetaContent(name): string | null {
  const meta = document.querySelector<HTMLMetaElement>(`meta[name="${name}"]`);
  return meta?.content ?? null;
}

const device: DeviceContextValue = { isMobile: isCameraCapableMobile() };

const trackEvent: typeof baseTrackEvent = (event, payload) => {
  const {
    flowPath,
    acuantSdkUpgradeABTestingEnabled,
    useAlternateSdk,
    acuantVersion,
    optedInToInPersonProofing,
  } = appRoot.dataset;
  return baseTrackEvent(event, {
    ...payload,
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
  cancelUrl: cancelURL,
  accountUrl: accountURL,
  idvInPersonUrl: inPersonURL,
  securityAndPrivacyHowItWorksUrl: securityAndPrivacyHowItWorksURL,
  inPersonFullAddressEntryEnabled,
  inPersonOutageMessageEnabled,
  inPersonOutageExpectedUpdateDate,
  optedInToInPersonProofing,
  usStatesTerritories = '',
  skipDocAuthFromHowToVerify,
  skipDocAuthFromHandoff,
  howToVerifyUrl,
  previousStepUrl,
  docAuthSelfieDesktopTestMode,
  locationsUrl: locationsURL,
  addressSearchUrl: addressSearchURL,
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
          addressSearchURL,
          inPersonOutageExpectedUpdateDate,
          inPersonOutageMessageEnabled: inPersonOutageMessageEnabled === 'true',
          inPersonFullAddressEntryEnabled: inPersonFullAddressEntryEnabled === 'true',
          optedInToInPersonProofing: optedInToInPersonProofing === 'true',
          usStatesTerritories: parsedUsStatesTerritories,
          skipDocAuthFromHowToVerify: skipDocAuthFromHowToVerify === 'true',
          skipDocAuthFromHandoff: skipDocAuthFromHandoff === 'true',
          howToVerifyURL: howToVerifyUrl,
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
              formData={formData}
              flowPath={flowPath}
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
                    <FailedCaptureAttemptsContextProvider
                      maxCaptureAttemptsBeforeNativeCamera={Number(
                        maxCaptureAttemptsBeforeNativeCamera,
                      )}
                      maxSubmissionAttemptsBeforeNativeCamera={Number(
                        maxSubmissionAttemptsBeforeNativeCamera,
                      )}
                      failedFingerprints={{ front: [], back: [] }}
                    >
                      <DocumentCapture onStepChange={() => extendSession(sessionsURL)} />
                    </FailedCaptureAttemptsContextProvider>
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
