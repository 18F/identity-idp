import { createContext, useContext, useMemo, useEffect, useState } from 'react';
import DeviceContext from './device';
import AnalyticsContext from './analytics';

/** @typedef {import('react').ReactNode} ReactNode */

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
 * @typedef AcuantJavaScriptWebSDK
 *
 * @prop {AcuantInitialize} initialize Acuant SDK initializer.
 */

/**
 * @typedef AcuantGlobals
 *
 * @prop {()=>void}               onAcuantSdkLoaded      Acuant initialization callback.
 * @prop {AcuantCamera}           AcuantCamera           Acuant camera API.
 * @prop {AcuantJavaScriptWebSDK} AcuantJavascriptWebSdk Acuant web SDK.
 */

/**
 * @typedef {typeof window & AcuantGlobals} AcuantGlobal
 */

/**
 * @typedef AcuantContextProviderProps
 *
 * @prop {string=} sdkSrc SDK source URL.
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

const AcuantContext = createContext({
  isReady: false,
  isAcuantLoaded: false,
  isError: false,
  isCameraSupported: /** @type {boolean?} */ (null),
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
  sdkSrc = '/acuant/11.4.3/AcuantJavascriptWebSdk.min.js',
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
  const value = useMemo(
    () => ({
      isReady,
      isAcuantLoaded,
      isError,
      isCameraSupported,
      endpoint,
      credentials,
      glareThreshold,
      sharpnessThreshold,
    }),
    [
      isReady,
      isAcuantLoaded,
      isError,
      isCameraSupported,
      endpoint,
      credentials,
      glareThreshold,
      sharpnessThreshold,
    ],
  );

  useEffect(() => {
    // If state is already ready (via consideration of device type), skip loading Acuant SDK.
    if (isReady) {
      return;
    }

    // Acuant SDK expects this global to be assigned at the time the script is
    // loaded, which is why the script element is manually appended to the DOM.
    const originalOnAcuantSdkLoaded = /** @type {AcuantGlobal} */ (window).onAcuantSdkLoaded;
    /** @type {AcuantGlobal} */ (window).onAcuantSdkLoaded = () => {
      /** @type {AcuantGlobal} */ (window).AcuantJavascriptWebSdk.initialize(
        credentials,
        endpoint,
        {
          onSuccess: () => {
            addPageAction({
              label: 'IdV: Acuant SDK loaded',
              payload: { success: true },
            });

            setIsCameraSupported(
              /** @type {AcuantGlobal} */ (window).AcuantCamera.isCameraSupported,
            );
            setIsReady(true);
            setIsAcuantLoaded(true);
          },
          onFail(code, description) {
            addPageAction({
              label: 'IdV: Acuant SDK loaded',
              payload: {
                success: false,
                code,
                description,
              },
            });

            setIsError(true);
          },
        },
      );
    };

    const script = document.createElement('script');
    script.async = true;
    script.src = sdkSrc;
    script.onerror = () => setIsError(true);
    document.body.appendChild(script);

    return () => {
      /** @type {AcuantGlobal} */ (window).onAcuantSdkLoaded = originalOnAcuantSdkLoaded;
      document.body.removeChild(script);
    };
  }, []);

  return <AcuantContext.Provider value={value}>{children}</AcuantContext.Provider>;
}

export const Provider = AcuantContextProvider;

export default AcuantContext;
