import { createContext, useContext, useEffect, useState } from 'react';
import type { ReactNode } from 'react';
import useObjectMemo from '@18f/identity-react-hooks/use-object-memo';
import AnalyticsContext from './analytics';
import DeviceContext from './device';
import SelfieCaptureContext from './selfie-capture';

/**
 * Global declarations
 */
declare let AcuantCamera: AcuantCameraInterface;

declare global {
  interface AcuantJavascriptWebSdkInterface {
    setUnexpectedErrorCallback(arg0: (error: string) => void): unknown;
    initialize: AcuantInitialize;
    START_FAIL_CODE: string;
    REPEAT_FAIL_CODE: string;
    SEQUENCE_BREAK_CODE: string;
    start?: AcuantWorkersInitialize;
    startWorkers?: AcuantWorkersInitialize;
  }
}

declare global {
  interface Window {
    /**
     * Document load callback to assign Javascript Web SDK globals
     */
    loadAcuantSdk: () => void;
    /**
     * Acuant configuration
     */
    acuantConfig: AcuantConfig;
    /**
     * Possible AcuantJavascriptWebSdk on the window object (11.5.0)
     */
    AcuantJavascriptWebSdk: AcuantJavascriptWebSdkInterface;
    /**
     * Possible AcuantCamera on the window object (11.5.0)
     */
    AcuantCamera: AcuantCameraInterface;
  }
}

/**
 * Some of the other modules still refer to
 * AcuantGlobal, which should be equivalent to the
 * Window
 */
export type AcuantGlobal = Window;

/**
 * @see https://github.com/Acuant/JavascriptWebSDKV11/blob/11.4.3/SimpleHTMLApp/webSdk/dist/AcuantJavascriptWebSdk.js#L1025-L1027
 * @see https://github.com/Acuant/JavascriptWebSDKV11/blob/11.4.3/SimpleHTMLApp/webSdk/dist/AcuantJavascriptWebSdk.js#L1049
 */
interface AcuantConfig {
  path: string;
}

interface AcuantCameraInterface {
  isCameraSupported: boolean;
}

/**
 * @see https://github.com/Acuant/JavascriptWebSDKV11/blob/11.4.4/SimpleHTMLApp/webSdk/dist/AcuantJavascriptWebSdk.js#L1327-L1353
 */
type AcuantInitializeCode = 1 | 2 | 400 | 401 | 403;

interface AcuantCallbackOptions {
  onSuccess: () => void;
  onFail: (code: AcuantInitializeCode, description: string) => void;
}

type AcuantInitialize = (
  credentials: string | null,
  endpoint: string | null,
  callbackOptions?: AcuantCallbackOptions,
) => void;

type AcuantWorkersInitialize = (callback: () => void) => void;

interface AcuantContextProviderProps {
  /**
   * SDK source URL.
   */
  sdkSrc: string;
  /**
   * Camera JavaScript source URL.
   */
  cameraSrc: string;
  /**
   * OpenCV JavaScript source URL. Required for passive liveness.
   */
  passiveLivenessOpenCVSrc: string;
  /**
   * Passive Liveness (Selfie) JavaScript source URL.
   * If this is undefined, it means the selfie feature is
   * disabled.
   */
  passiveLivenessSrc: string | undefined;
  /**
   * Loaded by AcuantPassiveLivness directly. We load it for caching purposes to speed up the AcuantSelfieCamera startup
   */
  faceLandmarkWeightsSrc: string | undefined;
  /**
   * Loaded by AcuantPassiveLivness directly. We load it for caching purposes to speed up the AcuantSelfieCamera startup
   */
  tinyFaceLandmarkWeightsSrc: string | undefined;
  /**
   * Loaded by AcuantPassiveLivness directly. We load it for caching purposes to speed up the AcuantSelfieCamera startup
   */
  faceLandmarkModelSrc: string | undefined;
  /**
   * Loaded by AcuantPassiveLivness directly. We load it for caching purposes to speed up the AcuantSelfieCamera startup
   */
  faceLandmarkShardSrc: string | undefined;
  /**
   * SDK credentials.
   */
  credentials: string | null;
  /**
   * Endpoint to submit payload.
   */
  endpoint: string | null;
  /**
   * Minimum acceptable glare score for images.
   */
  glareThreshold: number | null;
  /**
   * Minimum acceptable sharpness score for images.
   */
  sharpnessThreshold: number | null;
  /**
   * Child element
   */
  children: ReactNode;
}

export type AcuantCaptureMode = 'AUTO' | 'TAP';

/**
 * Returns the containing directory of the given file, including a trailing slash.
 */
export const dirname = (file: string): string => file.split('/').slice(0, -1).concat('').join('/');

interface AcuantContextInterface {
  isReady: boolean;
  isAcuantLoaded: boolean;
  isError: boolean;
  isCameraSupported: boolean | null;
  isActive: boolean;
  setIsActive: (nextIsActive: boolean) => void;
  acuantCaptureMode: AcuantCaptureMode;
  setAcuantCaptureMode: (type: AcuantCaptureMode) => void;
  credentials: string | null;
  glareThreshold: number | null;
  sharpnessThreshold: number | null;
  endpoint: string | null;
}

const AcuantContext = createContext<AcuantContextInterface>({
  isReady: false,
  isAcuantLoaded: false,
  isError: false,
  isCameraSupported: null as boolean | null,
  isActive: false,
  setIsActive: () => {},
  acuantCaptureMode: 'AUTO',
  setAcuantCaptureMode: () => {},
  credentials: null,
  glareThreshold: null,
  sharpnessThreshold: null,
  endpoint: null as string | null,
});

AcuantContext.displayName = 'AcuantContext';

/**
 * Returns a found AcuantJavascriptWebSdk
 * object, if one is available.
 * Depending on the SDK version,
 * will use either startWorkers (11.8.2) or start (11.9.1)
 */
const getActualAcuantJavascriptWebSdk = (): AcuantJavascriptWebSdkInterface => {
  if (
    window.AcuantJavascriptWebSdk &&
    typeof window.AcuantJavascriptWebSdk.startWorkers === 'function' &&
    typeof window.AcuantJavascriptWebSdk.start !== 'function'
  ) {
    return {
      ...window.AcuantJavascriptWebSdk,
      start(...args) {
        window.AcuantJavascriptWebSdk.startWorkers?.(...args);
      },
    };
  }
  if (window.AcuantJavascriptWebSdk && typeof window.AcuantJavascriptWebSdk.start === 'function') {
    return window.AcuantJavascriptWebSdk;
  }
  if (!window.AcuantJavascriptWebSdk) {
    // eslint-disable-next-line no-console
    console.error('AcuantJavascriptWebSdk is not defined in the global scope');
  }
  return window.AcuantJavascriptWebSdk;
};

/**
 * Returns a found AcuantCamera
 * object, if one is available.
 * This function normalizes differences between
 * the 11.5.0 and 11.7.0 SDKs. The former attached
 * the object to the global window, while the latter
 * sets the object in the global (but non-window)
 * scope.
 */
const getActualAcuantCamera = (): AcuantCameraInterface => {
  if (window.AcuantCamera) {
    return window.AcuantCamera;
  }
  if (typeof AcuantCamera === 'undefined') {
    // eslint-disable-next-line no-console
    console.error('AcuantCamera is not defined in the global scope');
  }
  return AcuantCamera;
};

function AcuantContextProvider({
  sdkSrc,
  cameraSrc,
  passiveLivenessOpenCVSrc,
  passiveLivenessSrc,
  faceLandmarkWeightsSrc,
  tinyFaceLandmarkWeightsSrc,
  faceLandmarkModelSrc,
  faceLandmarkShardSrc,
  credentials = null,
  endpoint = null,
  glareThreshold,
  sharpnessThreshold,
  children,
}: AcuantContextProviderProps) {
  const { isMobile } = useContext(DeviceContext);
  const { trackEvent } = useContext(AnalyticsContext);
  const { isSelfieCaptureEnabled } = useContext(SelfieCaptureContext);
  // Only mobile devices should load the Acuant SDK. Consider immediately ready otherwise.
  const [isReady, setIsReady] = useState(!isMobile);
  const [isAcuantLoaded, setIsAcuantLoaded] = useState(false);
  const [isError, setIsError] = useState(false);
  // If the user is on a mobile device, it can't be known that the camera is supported until after
  // Acuant SDK loads, so assign a value of `null` as representing this unknown state. Other device
  // types should treat camera as unsupported, since it's not relevant for Acuant SDK usage.
  const [isCameraSupported, setIsCameraSupported] = useState(isMobile ? null : false);
  const [isActive, setIsActive] = useState(false);
  const [acuantCaptureMode, setAcuantCaptureMode] = useState<AcuantCaptureMode>('AUTO');

  const value = useObjectMemo({
    isReady,
    isAcuantLoaded,
    isError,
    isCameraSupported,
    isActive,
    setIsActive,
    acuantCaptureMode,
    setAcuantCaptureMode,
    endpoint,
    credentials,
    glareThreshold,
    sharpnessThreshold,
  });

  useEffect(() => {
    // If state is already ready (via consideration of device type), skip loading Acuant SDK.
    if (isReady) {
      return;
    }

    // Acuant SDK expects this global to be assigned at the time the script is
    // loaded, which is why the script element is manually appended to the DOM.
    function onAcuantSdkLoaded() {
      const { loadAcuantSdk } = window;
      // Normally, Acuant SDK would call this itself, but because it does so as part of a
      // DOMContentLoaded event handler, it wouldn't be called if the page is already loaded.
      if (!window.AcuantJavascriptWebSdk) {
        if (typeof loadAcuantSdk !== 'function') {
          return;
        }

        loadAcuantSdk();
      }
      window.AcuantJavascriptWebSdk = getActualAcuantJavascriptWebSdk();

      // Unclear if/how this is called. Implemented just in case, but this is untested.
      window.AcuantJavascriptWebSdk.setUnexpectedErrorCallback((errorMessage) => {
        trackEvent('idv_sdk_error_before_init', {
          success: false,
          error_message: errorMessage,
          liveness_checking_required: isSelfieCaptureEnabled,
        });
      });

      window.AcuantJavascriptWebSdk.initialize(credentials, endpoint, {
        onSuccess: () => {
          window.AcuantJavascriptWebSdk.start?.(() => {
            window.AcuantCamera = getActualAcuantCamera();
            const { isCameraSupported: nextIsCameraSupported } = window.AcuantCamera;
            trackEvent('IdV: Acuant SDK loaded', {
              success: true,
              isCameraSupported: nextIsCameraSupported,
              liveness_checking_required: isSelfieCaptureEnabled,
            });

            setIsCameraSupported(nextIsCameraSupported);
            setIsReady(true);
            setIsAcuantLoaded(true);
          });
        },
        onFail(code, description) {
          trackEvent('IdV: Acuant SDK loaded', {
            success: false,
            code,
            description,
            liveness_checking_required: isSelfieCaptureEnabled,
          });

          setIsError(true);
        },
      });
    }

    const originalAcuantConfig = window.acuantConfig;
    window.acuantConfig = { path: dirname(sdkSrc) };

    // SDK Main script load
    const sdkScript = document.createElement('script');
    sdkScript.src = sdkSrc;
    sdkScript.onload = onAcuantSdkLoaded;
    sdkScript.onerror = () => setIsError(true);
    sdkScript.dataset.acuantSdk = '';
    document.body.appendChild(sdkScript);
    // Camera script load
    const cameraScript = document.createElement('script');
    cameraScript.async = true;
    cameraScript.src = cameraSrc;
    cameraScript.onerror = () => setIsError(true);
    document.body.appendChild(cameraScript);
    // Passive liveness (Selfie) script load
    // Create the empty script regardless of whether we load
    // to make the cleanup function simpler
    const passiveLivenessScript = document.createElement('script');
    // Open CV script load. Open CV is required only for passive liveness
    const passiveLivenessOpenCVScript = document.createElement('script');
    // The following four scripts are used interally by the AcuantPassiveLiveness script
    // Load them here so they are cached, which greatly reduces the apparent
    // startup time for the AcuantSelfieCamera on slow networks.
    const tinyFaceLandmarkWeights = document.createElement('script');
    const faceLandmarkWeights = document.createElement('script');
    const faceLandmarkModel = document.createElement('script');
    const faceLandmarkShard = document.createElement('script');
    if (passiveLivenessSrc) {
      passiveLivenessScript.async = true;
      passiveLivenessScript.src = passiveLivenessSrc;
      passiveLivenessScript.onerror = () => setIsError(true);
      passiveLivenessOpenCVScript.async = true;
      passiveLivenessOpenCVScript.src = passiveLivenessOpenCVSrc;
      passiveLivenessOpenCVScript.onerror = () => setIsError(true);
      if (tinyFaceLandmarkWeightsSrc) {
        tinyFaceLandmarkWeights.async = true;
        tinyFaceLandmarkWeights.src = tinyFaceLandmarkWeightsSrc;
        tinyFaceLandmarkWeights.onerror = () => setIsError(true);
      }
      if (faceLandmarkWeightsSrc) {
        faceLandmarkWeights.async = true;
        faceLandmarkWeights.src = faceLandmarkWeightsSrc;
        faceLandmarkWeights.onerror = () => setIsError(true);
      }
      if (faceLandmarkModelSrc) {
        faceLandmarkModel.async = true;
        faceLandmarkModel.src = faceLandmarkModelSrc;
        faceLandmarkModel.onerror = () => setIsError(true);
      }
      if (faceLandmarkShardSrc) {
        faceLandmarkShard.async = true;
        faceLandmarkShard.src = faceLandmarkShardSrc;
        faceLandmarkShard.onerror = () => setIsError(true);
      }
    }
    document.body.appendChild(passiveLivenessScript);
    document.body.appendChild(passiveLivenessOpenCVScript);
    document.body.appendChild(faceLandmarkWeights);
    document.body.appendChild(tinyFaceLandmarkWeights);
    document.body.appendChild(faceLandmarkModel);
    document.body.appendChild(faceLandmarkShard);

    return () => {
      window.acuantConfig = originalAcuantConfig;
      sdkScript.onload = null;
      document.body.removeChild(sdkScript);
      document.body.removeChild(cameraScript);
      document.body.removeChild(passiveLivenessScript);
      document.body.removeChild(passiveLivenessOpenCVScript);
      document.body.removeChild(faceLandmarkWeights);
      document.body.removeChild(tinyFaceLandmarkWeights);
      document.body.removeChild(faceLandmarkModel);
      document.body.removeChild(faceLandmarkShard);
    };
  }, []);

  return <AcuantContext.Provider value={value}>{children}</AcuantContext.Provider>;
}

export const Provider = AcuantContextProvider;
export default AcuantContext;
