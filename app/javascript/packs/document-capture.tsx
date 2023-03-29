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
} from '@18f/identity-document-capture';
import { isCameraCapableMobile } from '@18f/identity-device';
import { FlowContext } from '@18f/identity-verify-flow';
import { trackEvent as baseTrackEvent } from '@18f/identity-analytics';
import { request } from '@18f/identity-request';
import type { FlowPath, DeviceContextValue } from '@18f/identity-document-capture';

/**
 * @see MarketingSiteContextProvider
 * @see FailedCaptureAttemptsContext
 * @see UploadContext
 */
interface AppRootData {
  helpCenterRedirectUrl: string;
  maxCaptureAttemptsBeforeTips: string;
  maxAttemptsBeforeNativeCamera: string;
  acuantSdkUpgradeABTestingEnabled: string;
  useAlternateSdk: string;
  acuantVersion: string;
  flowPath: FlowPath;
  cancelUrl: string;
  idvInPersonUrl?: string;
  securityAndPrivacyHowItWorksUrl: string;
  inPersonCtaVariantTestingEnabled: boolean;
  inPersonCtaVariantActive: string;
}

const appRoot = document.getElementById('document-capture-form')!;
const isMockClient = appRoot.hasAttribute('data-mock-client');
const keepAliveEndpoint = appRoot.getAttribute('data-keep-alive-endpoint')!;
const glareThreshold = Number(appRoot.getAttribute('data-glare-threshold')) ?? undefined;
const sharpnessThreshold = Number(appRoot.getAttribute('data-sharpness-threshold')) ?? undefined;

function getServiceProvider() {
  const { spName: name = null, failureToProofUrl: failureToProofURL = '' } = appRoot.dataset;

  return { name, failureToProofURL };
}

function getBackgroundUploadURLs(): Record<'front' | 'back', string> {
  return ['front', 'back'].reduce((result, key) => {
    const url = appRoot.getAttribute(`data-${key}-image-upload-url`);
    if (url) {
      result[key] = url;
    }

    return result;
  }, {} as Record<'front' | 'back', string>);
}

function getMetaContent(name): string | null {
  const meta = document.querySelector<HTMLMetaElement>(`meta[name="${name}"]`);
  return meta?.content ?? null;
}

const device: DeviceContextValue = { isMobile: isCameraCapableMobile() };

const trackEvent: typeof baseTrackEvent = (event, payload) => {
  const { flowPath, acuantSdkUpgradeABTestingEnabled, useAlternateSdk, acuantVersion } =
    appRoot.dataset;
  return baseTrackEvent(event, {
    ...payload,
    flow_path: flowPath,
    acuant_sdk_upgrade_a_b_testing_enabled: acuantSdkUpgradeABTestingEnabled,
    use_alternate_sdk: useAlternateSdk,
    acuant_version: acuantVersion,
  });
};

(async () => {
  const backgroundUploadURLs = getBackgroundUploadURLs();
  const isAsyncForm = Object.keys(backgroundUploadURLs).length > 0;

  const formData: Record<string, any> = {
    document_capture_session_uuid: appRoot.getAttribute('data-document-capture-session-uuid'),
    locale: document.documentElement.lang,
  };

  let backgroundUploadEncryptKey;
  if (isAsyncForm) {
    backgroundUploadEncryptKey = await window.crypto.subtle.generateKey(
      {
        name: 'AES-GCM',
        length: 256,
      },
      true,
      ['encrypt', 'decrypt'],
    );

    const exportedKey = await window.crypto.subtle.exportKey('raw', backgroundUploadEncryptKey);
    formData.encryption_key = btoa(String.fromCharCode(...new Uint8Array(exportedKey)));
    formData.step = 'verify_document';
  }

  const keepAlive = () => request(keepAliveEndpoint, { method: 'POST' });

  const {
    helpCenterRedirectUrl: helpCenterRedirectURL,
    maxCaptureAttemptsBeforeTips,
    maxCaptureAttemptsBeforeNativeCamera,
    maxSubmissionAttemptsBeforeNativeCamera,
    acuantVersion,
    flowPath,
    cancelUrl: cancelURL,
    idvInPersonUrl: inPersonURL,
    securityAndPrivacyHowItWorksUrl: securityAndPrivacyHowItWorksURL,
    inPersonCtaVariantTestingEnabled,
    inPersonCtaVariantActive,
  } = appRoot.dataset as DOMStringMap & AppRootData;

  const App = composeComponents(
    [MarketingSiteContextProvider, { helpCenterRedirectURL, securityAndPrivacyHowItWorksURL }],
    [DeviceContext.Provider, { value: device }],
    [
      InPersonContext.Provider,
      {
        value: {
          inPersonCtaVariantTestingEnabled: inPersonCtaVariantTestingEnabled === true,
          inPersonCtaVariantActive,
          inPersonURL,
        },
      },
    ],
    [AnalyticsContextProvider, { trackEvent }],
    [
      AcuantContextProvider,
      {
        sdkSrc: acuantVersion && `/acuant/${acuantVersion}/AcuantJavascriptWebSdk.min.js`,
        cameraSrc: acuantVersion && `/acuant/${acuantVersion}/AcuantCamera.min.js`,
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
        backgroundUploadURLs,
        backgroundUploadEncryptKey,
        formData,
        flowPath,
      },
    ],
    [
      FlowContext.Provider,
      {
        value: {
          cancelURL,
          currentStep: 'document_capture',
        },
      },
    ],
    [ServiceProviderContextProvider, { value: getServiceProvider() }],
    [
      FailedCaptureAttemptsContextProvider,
      {
        maxFailedAttemptsBeforeTips: Number(maxCaptureAttemptsBeforeTips),
        maxCaptureAttemptsBeforeNativeCamera: Number(maxCaptureAttemptsBeforeNativeCamera),
        maxSubmissionAttemptsBeforeNativeCamera: Number(maxSubmissionAttemptsBeforeNativeCamera),
      },
    ],
    [DocumentCapture, { isAsyncForm, onStepChange: keepAlive }],
  );

  render(<App />, appRoot);
})();
