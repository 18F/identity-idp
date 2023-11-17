import { render } from 'react-dom';
import { composeComponents } from '@18f/identity-compose-components';
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
  FeatureFlagContext,
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
  exitUrl: string;
  idvInPersonUrl?: string;
  securityAndPrivacyHowItWorksUrl: string;
  uiNotReadySectionEnabled: string;
  uiExitQuestionSectionEnabled: string;
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
  const docAuthSelfieCaptureObject = docAuthSelfieCapture ? JSON.parse(docAuthSelfieCapture) : {};
  return !!docAuthSelfieCaptureObject?.enabled;
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
    phoneQuestionAbTestBucket,
    phoneWithCamera,
  } = appRoot.dataset;
  return baseTrackEvent(event, {
    ...payload,
    flow_path: flowPath,
    acuant_sdk_upgrade_a_b_testing_enabled: acuantSdkUpgradeABTestingEnabled,
    use_alternate_sdk: useAlternateSdk,
    acuant_version: acuantVersion,
    phone_question_ab_test_bucket: phoneQuestionAbTestBucket,
    phone_with_camera: phoneWithCamera,
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
  exitUrl: exitURL,
  accountUrl: accountURL,
  idvInPersonUrl: inPersonURL,
  securityAndPrivacyHowItWorksUrl: securityAndPrivacyHowItWorksURL,
  inPersonFullAddressEntryEnabled,
  inPersonOutageMessageEnabled,
  inPersonOutageExpectedUpdateDate,
  usStatesTerritories = '',
  phoneWithCamera = '',
  uiNotReadySectionEnabled = '',
  uiExitQuestionSectionEnabled = '',
} = appRoot.dataset as DOMStringMap & AppRootData;

let parsedUsStatesTerritories = [];
try {
  parsedUsStatesTerritories = JSON.parse(usStatesTerritories);
} catch (e) {}

const App = composeComponents(
  [MarketingSiteContextProvider, { helpCenterRedirectURL, securityAndPrivacyHowItWorksURL }],
  [DeviceContext.Provider, { value: device }],
  [
    InPersonContext.Provider,
    {
      value: {
        inPersonURL,
        locationsURL: new URL('/verify/in_person/usps_locations', window.location.href).toString(),
        addressSearchURL: new URL('/api/addresses', window.location.href).toString(),
        inPersonOutageMessageEnabled: inPersonOutageMessageEnabled === 'true',
        inPersonOutageExpectedUpdateDate,
        inPersonFullAddressEntryEnabled: inPersonFullAddressEntryEnabled === 'true',
        usStatesTerritories: parsedUsStatesTerritories,
      },
    },
  ],
  [AnalyticsContextProvider, { trackEvent }],
  [
    AcuantContextProvider,
    {
      sdkSrc: acuantVersion && `/acuant/${acuantVersion}/AcuantJavascriptWebSdk.min.js`,
      cameraSrc: acuantVersion && `/acuant/${acuantVersion}/AcuantCamera.min.js`,
      passiveLivenessOpenCVSrc: acuantVersion && `/acuant/${acuantVersion}/opencv.min.js`,
      passiveLivenessSrc: getSelfieCaptureEnabled()
        ? acuantVersion && `/acuant/${acuantVersion}/AcuantPassiveLiveness.min.js`
        : undefined,
      credentials: getMetaContent('acuant-sdk-initialization-creds'),
      endpoint: getMetaContent('acuant-sdk-initialization-endpoint'),
      glareThreshold,
      sharpnessThreshold,
    },
  ],
  [
    UploadContextProvider,
    {
      endpoint: String(appRoot.getAttribute('data-endpoint')),
      statusEndpoint: String(appRoot.getAttribute('data-status-endpoint')),
      statusPollInterval: Number(appRoot.getAttribute('data-status-poll-interval-ms')),
      isMockClient,
      formData,
      flowPath,
      phoneWithCamera,
    },
  ],
  [
    FlowContext.Provider,
    {
      value: {
        accountURL,
        cancelURL,
        exitURL,
        currentStep: 'document_capture',
      },
    },
  ],
  [
    ServiceProviderContextProvider,
    {
      value: getServiceProvider(),
    },
  ],
  [
    FailedCaptureAttemptsContextProvider,
    {
      maxCaptureAttemptsBeforeNativeCamera: Number(maxCaptureAttemptsBeforeNativeCamera),
      maxSubmissionAttemptsBeforeNativeCamera: Number(maxSubmissionAttemptsBeforeNativeCamera),
    },
  ],
  [
    FeatureFlagContext.Provider,
    {
      value: {
        notReadySectionEnabled: String(uiNotReadySectionEnabled) === 'true',
        exitQuestionSectionEnabled: String(uiExitQuestionSectionEnabled) === 'true',
        selfieCaptureEnabled: getSelfieCaptureEnabled(),
      },
    },
  ],
  [
    DocumentCapture,
    {
      onStepChange: extendSession,
    },
  ],
);

render(<App />, appRoot);
