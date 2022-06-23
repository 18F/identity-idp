import { createContext, useContext, useEffect, useState } from 'react';
import useObjectMemo from '@18f/identity-react-hooks/use-object-memo';
import DeviceContext from './device';
import AnalyticsContext from './analytics';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef AcuantConfig
 *
 * @prop {string=} path Path from which to load SDK service worker.
 *
 * @see https://github.com/Acuant/JavascriptWebSDKV11/blob/11.4.3/SimpleHTMLApp/webSdk/dist/AcuantJavascriptWebSdk.js#L1025-L1027
 * @see https://github.com/Acuant/JavascriptWebSDKV11/blob/11.4.3/SimpleHTMLApp/webSdk/dist/AcuantJavascriptWebSdk.js#L1049
 */

/**
 * @typedef AcuantCamera
 *
 * @prop {boolean} isCameraSupported Whether camera is supported.
 */

/**
 * @typedef {1|2|400|401|403} AcuantInitializeCode Acuant initialization callback code.
 *
 * @see https://github.com/Acuant/JavascriptWebSDKV11/blob/11.4.4/SimpleHTMLApp/webSdk/dist/AcuantJavascriptWebSdk.js#L1327-L1353
 */

/**
 * @typedef AcuantCallbackOptions
 *
 * @prop {()=>void} onSuccess Success callback.
 * @prop {(code: AcuantInitializeCode, description: string)=>void} onFail Failure callback.
 */

/**
 * @typedef {(
 *   credentials: string?,
 *   endpoint: string?,
 *   callback: AcuantCallbackOptions,
 * )=>void} AcuantInitialize
 */

/**
 * @typedef {(callback: () => void)=>void} AcuantWorkersInitialize
 */

/**
 * @typedef AcuantJavaScriptWebSDK
 *
 * @prop {AcuantInitialize} initialize Acuant SDK initializer.
 * @prop {AcuantWorkersInitialize} startWorkers Acuant SDK workers initializer.
 * @prop {string} START_FAIL_CODE Error code when camera failed to start.
 * @prop {string} REPEAT_FAIL_CODE Error code if starting capture after a failure already occurred.
 * @prop {string} SEQUENCE_BREAK_CODE Error code when failure due to iOS 15 GPU Highwater.
 */

/**
 * @typedef AcuantPassiveLiveness
 *
 * @prop {(callback:(nextImageData:string)=>void)=>void} startSelfieCapture Start liveness capture.
 */

/**
 * @typedef AcuantGlobals
 *
 * @prop {() => void} loadAcuantSdk Document load callback to assign JavaScript Web SDK globals.
 * @prop {AcuantConfig=} acuantConfig Acuant configuration.
 * @prop {AcuantCamera} AcuantCamera Acuant camera API.
 * @prop {AcuantJavaScriptWebSDK} AcuantJavascriptWebSdk Acuant web SDK.
 * @prop {AcuantPassiveLiveness} AcuantPassiveLiveness Acuant Passive Liveness API.
 */

/**
 * @typedef {typeof window & AcuantGlobals} AcuantGlobal
 */

/**
 * @typedef AcuantContextProviderProps
 *
 * @prop {string=} sdkSrc SDK source URL.
 * @prop {string=} cameraSrc Camera JavaScript source URL.
 * @prop {string?=} credentials SDK credentials.
 * @prop {string?=} endpoint Endpoint to submit payload.
 * @prop {number=} glareThreshold Minimum acceptable glare score for images.
 * @prop {number=} sharpnessThreshold Minimum acceptable sharpness score for images.
 * @prop {ReactNode} children Child element.
 */

/**
 * The minimum glare score value to be considered acceptable.
 *
 * @type {number}
 */
export const DEFAULT_ACCEPTABLE_GLARE_SCORE = 30;

/**
 * The minimum sharpness score value to be considered acceptable.
 *
 * @type {number}
 */
export const DEFAULT_ACCEPTABLE_SHARPNESS_SCORE = 30;

/**
 * Returns the containing directory of the given file, including a trailing slash.
 *
 * @param {string} file
 *
 * @return {string}
 */
export const dirname = (file) => file.split('/').slice(0, -1).concat('').join('/');

const AcuantContext = createContext({
  isReady: false,
  isAcuantLoaded: false,
  isError: false,
  isCameraSupported: /** @type {boolean?} */ (null),
  isActive: false,
  setIsActive: /** @type {(nextIsActive: boolean) => void} */ (() => {}),
  credentials: /** @type {string?} */ (null),
  glareThreshold: DEFAULT_ACCEPTABLE_GLARE_SCORE,
  sharpnessThreshold: DEFAULT_ACCEPTABLE_SHARPNESS_SCORE,
  endpoint: /** @type {string?} */ (null),
});

AcuantContext.displayName = 'AcuantContext';

/**
 * @param {AcuantContextProviderProps} props Props object.
 */
function AcuantContextProvider({
  sdkSrc = '/acuant/11.5.0/AcuantJavascriptWebSdk.min.js',
  cameraSrc = '/acuant/11.5.0/AcuantCamera.min.js',
  credentials = null,
  endpoint = null,
  glareThreshold = DEFAULT_ACCEPTABLE_GLARE_SCORE,
  sharpnessThreshold = DEFAULT_ACCEPTABLE_SHARPNESS_SCORE,
  children,
}) {
  const { isMobile } = useContext(DeviceContext);
  const { addPageAction } = useContext(AnalyticsContext);
  // Only mobile devices should load the Acuant SDK. Consider immediately ready otherwise.
  const [isReady, setIsReady] = useState(!isMobile);
  const [isAcuantLoaded, setIsAcuantLoaded] = useState(false);
  const [isError, setIsError] = useState(false);
  // If the user is on a mobile device, it can't be known that the camera is supported until after
  // Acuant SDK loads, so assign a value of `null` as representing this unknown state. Other device
  // types should treat camera as unsupported, since it's not relevant for Acuant SDK usage.
  const [isCameraSupported, setIsCameraSupported] = useState(isMobile ? null : false);
  const [isActive, setIsActive] = useState(false);
  const value = useObjectMemo({
    isReady,
    isAcuantLoaded,
    isError,
    isCameraSupported,
    isActive,
    setIsActive,
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
      const { loadAcuantSdk, AcuantJavascriptWebSdk } = /** @type {AcuantGlobal} */ (window);

      // Normally, Acuant SDK would call this itself, but because it does so as part of a
      // DOMContentLoaded event handler, it wouldn't be called if the page is already loaded.
      if (!AcuantJavascriptWebSdk) {
        if (typeof loadAcuantSdk !== 'function') {
          return;
        }

        loadAcuantSdk();
      }

      /** @type {AcuantGlobal} */ (window).AcuantJavascriptWebSdk.initialize(
        credentials,
        endpoint,
        {
          onSuccess: () => {
            /** @type {AcuantGlobal} */ (window).AcuantJavascriptWebSdk.startWorkers(() => {
              const { isCameraSupported: nextIsCameraSupported } = /** @type {AcuantGlobal} */ (
                window
              ).AcuantCamera;

              addPageAction('IdV: Acuant SDK loaded', {
                success: true,
                isCameraSupported: nextIsCameraSupported,
              });

              setIsCameraSupported(nextIsCameraSupported);
              setIsReady(true);
              setIsAcuantLoaded(true);
            });
          },
          onFail(code, description) {
            addPageAction('IdV: Acuant SDK loaded', {
              success: false,
              code,
              description,
            });

            setIsError(true);
          },
        },
      );
    }

    const originalAcuantConfig = /** @type {AcuantGlobal} */ (window).acuantConfig;
    /** @type {AcuantGlobal} */ (window).acuantConfig = { path: dirname(sdkSrc) };

    const sdkScript = document.createElement('script');
    sdkScript.src = sdkSrc;
    sdkScript.onload = onAcuantSdkLoaded;
    sdkScript.onerror = () => setIsError(true);
    sdkScript.dataset.acuantSdk = '';
    document.body.appendChild(sdkScript);
    const cameraScript = document.createElement('script');
    cameraScript.async = true;
    cameraScript.src = cameraSrc;
    cameraScript.onerror = () => setIsError(true);
    document.body.appendChild(cameraScript);

    return () => {
      /** @type {AcuantGlobal} */ (window).acuantConfig = originalAcuantConfig;
      sdkScript.onload = null;
      document.body.removeChild(sdkScript);
      document.body.removeChild(cameraScript);
    };
  }, []);

  return <AcuantContext.Provider value={value}>{children}</AcuantContext.Provider>;
}

export const Provider = AcuantContextProvider;

export default AcuantContext;
