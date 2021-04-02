import {
  forwardRef,
  useContext,
  useRef,
  useState,
  useMemo,
  useEffect,
  useImperativeHandle,
} from 'react';
import AnalyticsContext from '../context/analytics';
import AcuantContext from '../context/acuant';
import AcuantCaptureCanvas from './acuant-capture-canvas';
import FileInput from './file-input';
import FullScreen from './full-screen';
import Button from './button';
import useI18n from '../hooks/use-i18n';
import DeviceContext from '../context/device';
import UploadContext from '../context/upload';
import useIfStillMounted from '../hooks/use-if-still-mounted';
import './acuant-capture.scss';

/** @typedef {import('react').ReactNode} ReactNode */
/** @typedef {import('./acuant-capture-canvas').AcuantSuccessResponse} AcuantSuccessResponse */
/** @typedef {import('./acuant-capture-canvas').AcuantDocumentType} AcuantDocumentType */

/**
 * @typedef {"id"|"passport"|"none"} AcuantDocumentTypeLabel
 */

/**
 * @typedef {"success"|"glare"|"blurry"} AcuantImageAssessment
 */

/**
 * @typedef {"acuant"|"upload"} ImageSource
 */

/**
 * @typedef ImageAnalyticsPayload
 *
 * @prop {number?} width Image width, or null if unknown.
 * @prop {number?} height Image height, or null if unknown.
 * @prop {string?} mimeType Mime type, or null if unknown.
 * @prop {ImageSource} source Method by which image was added.
 */

/**
 * @typedef _AcuantImageAnalyticsPayload
 *
 * @prop {AcuantDocumentTypeLabel} documentType
 * @prop {number} dpi
 * @prop {number} moire
 * @prop {number} glare
 * @prop {number} glareScoreThreshold
 * @prop {boolean} isAssessedAsGlare
 * @prop {number} sharpness
 * @prop {number} sharpnessScoreThreshold
 * @prop {boolean} isAssessedAsBlurry
 * @prop {AcuantImageAssessment} assessment
 */

/**
 * @typedef {ImageAnalyticsPayload & _AcuantImageAnalyticsPayload} AcuantImageAnalyticsPayload
 */

/**
 * @typedef AcuantPassiveLiveness
 *
 * @prop {(callback:(nextImageData:string)=>void)=>void} startSelfieCapture Start liveness capture.
 */

/**
 * @typedef AcuantGlobals
 *
 * @prop {AcuantPassiveLiveness} AcuantPassiveLiveness Acuant Passive Liveness API.
 */

/**
 * @typedef {typeof window & AcuantGlobals} AcuantGlobal
 */

/**
 * @typedef AcuantCaptureProps
 *
 * @prop {string} label Label associated with file input.
 * @prop {string=} bannerText Optional banner text to show in file input.
 * @prop {string|Blob|null|undefined} value Current value.
 * @prop {(nextValue:string|Blob|null)=>void} onChange Callback receiving next value on change.
 * @prop {'user'=} capture Facing mode of capture. If capture is not specified and a camera is
 * supported, defaults to the Acuant environment camera capture.
 * @prop {string=} className Optional additional class names.
 * @prop {boolean=} allowUpload Whether to allow file upload. Defaults to `true`.
 * @prop {ReactNode=} errorMessage Error to show.
 * @prop {string} name Prefix to prepend to user action analytics labels.
 */

/**
 * The minimum glare score value to be considered acceptable.
 *
 * @type {number}
 */
export const ACCEPTABLE_GLARE_SCORE = 50;

/**
 * The minimum sharpness score value to be considered acceptable.
 *
 * @type {number}
 */
export const ACCEPTABLE_SHARPNESS_SCORE = 50;

/**
 * Returns a human-readable document label corresponding to the given document type constant.
 *
 * @param {AcuantDocumentType} documentType
 *
 * @return {AcuantDocumentTypeLabel} Human-readable document label.
 */
function getDocumentTypeLabel(documentType) {
  switch (documentType) {
    case 1:
      return 'id';
    case 2:
      return 'passport';
    default:
      return 'none';
  }
}

/**
 * @param {import('./acuant-capture-canvas').AcuantCaptureFailureError} error
 *
 * @return {string}
 */
export function getNormalizedAcuantCaptureFailureMessage(error) {
  if (error instanceof Error) {
    return 'User or system denied camera access';
  }

  if (!error) {
    return 'Cropping failure';
  }

  switch (error) {
    case 'Camera not supported.':
      return 'Camera not supported';
    case 'Missing HTML elements.':
      return 'Required page elements are not available';
    case 'already started.':
    case 'already started':
      return 'Capture already started';
    default:
      return 'Unknown error';
  }
}

/**
 * @param {File} file Image file.
 *
 * @return {Promise<{width: number?, height: number?}>}
 */
function getImageDimensions(file) {
  let objectURL;
  return file.type.indexOf('image/') === 0
    ? new Promise((resolve) => {
        objectURL = window.URL.createObjectURL(file);
        const image = new window.Image();
        image.onload = () => resolve({ width: image.width, height: image.height });
        image.onerror = () => resolve({ width: null, height: null });
        image.src = objectURL;
      }).then(({ width, height }) => {
        window.URL.revokeObjectURL(objectURL);
        return { width, height };
      })
    : Promise.resolve({ width: null, height: null });
}

/**
 * Returns an element serving as an enhanced FileInput, supporting direct capture using Acuant SDK
 * in supported devices.
 *
 * @param {AcuantCaptureProps} props Props object.
 */
function AcuantCapture(
  {
    label,
    bannerText,
    value,
    onChange = () => {},
    capture,
    className,
    allowUpload = true,
    errorMessage,
    name,
  },
  ref,
) {
  const { isReady, isAcuantLoaded, isError, isCameraSupported } = useContext(AcuantContext);
  const { isMockClient } = useContext(UploadContext);
  const { addPageAction } = useContext(AnalyticsContext);
  const inputRef = useRef(/** @type {?HTMLInputElement} */ (null));
  const isForceUploading = useRef(false);
  const [isCapturingEnvironment, setIsCapturingEnvironment] = useState(false);
  const [ownErrorMessage, setOwnErrorMessage] = useState(/** @type {?string} */ (null));
  const ifStillMounted = useIfStillMounted();
  useMemo(() => setOwnErrorMessage(null), [value]);
  const { isMobile } = useContext(DeviceContext);
  const { t, formatHTML } = useI18n();
  const hasCapture = !isError && (isReady ? isCameraSupported : isMobile);
  useEffect(() => {
    // If capture had started before Acuant was ready, stop capture if readiness reveals that no
    // capture is supported. This takes advantage of the fact that state setter is noop if value of
    // `isCapturing` is already false.
    if (!hasCapture) {
      setIsCapturingEnvironment(false);
    }
  }, [hasCapture]);
  useImperativeHandle(ref, () => inputRef.current);

  /**
   * Calls onChange with next value and resets any errors which may be present.
   *
   * @param {Blob|string|null} nextValue Next value.
   */
  function onChangeAndResetError(nextValue) {
    setOwnErrorMessage(null);
    onChange(nextValue);
  }

  /**
   * Handler for file input change events.
   *
   * @param {File?} nextValue Next value, if set.
   */
  function onUpload(nextValue) {
    if (nextValue) {
      getImageDimensions(nextValue).then(({ width, height }) => {
        /** @type {ImageAnalyticsPayload} */
        const analyticsPayload = {
          width,
          height,
          mimeType: nextValue.type,
          source: 'upload',
        };

        addPageAction({
          label: `IdV: ${name} image added`,
          payload: analyticsPayload,
        });
      });
    }

    onChangeAndResetError(nextValue);
  }

  /**
   * Responds to a click by starting capture if supported in the environment, or triggering the
   * default file picker prompt. The click event may originate from the file input itself, or
   * another element which aims to trigger the prompt of the file input.
   *
   * @param {import('react').MouseEvent} event Click event.
   */
  function startCaptureOrTriggerUpload(event) {
    if (event.target === inputRef.current) {
      const shouldStartEnvironmentCapture =
        hasCapture && capture !== 'user' && !isForceUploading.current;
      const shouldStartSelfieCapture =
        isAcuantLoaded && capture === 'user' && !isForceUploading.current;

      if (!allowUpload || shouldStartSelfieCapture || shouldStartEnvironmentCapture) {
        event.preventDefault();
      }

      if (shouldStartSelfieCapture) {
        /** @type {AcuantGlobal} */ (window).AcuantPassiveLiveness.startSelfieCapture(
          ifStillMounted((nextImageData) => {
            const dataURI = `data:image/jpeg;base64,${nextImageData}`;
            onChangeAndResetError(dataURI);
          }),
        );
      } else if (shouldStartEnvironmentCapture) {
        setIsCapturingEnvironment(true);
      }

      isForceUploading.current = false;
    } else {
      inputRef.current?.click();
    }
  }

  /**
   * Triggers upload to occur, regardless of support for direct capture. This is necessary since the
   * default behavior for interacting with the file input is intercepted when capture is supported.
   * Calling `forceUpload` will flag the click handling to skip intercepting the event as capture.
   */
  function forceUpload() {
    if (!inputRef.current) {
      return;
    }

    isForceUploading.current = true;

    const originalCapture = inputRef.current.getAttribute('capture');

    if (originalCapture !== null) {
      inputRef.current.removeAttribute('capture');
    }

    inputRef.current.click();

    if (originalCapture !== null) {
      inputRef.current.setAttribute('capture', originalCapture);
    }
  }

  /**
   * @param {AcuantSuccessResponse} nextCapture
   */
  function onAcuantImageCaptureSuccess(nextCapture) {
    const { image, cardType, dpi, moire, glare, sharpness } = nextCapture;
    const isAssessedAsGlare = glare < ACCEPTABLE_GLARE_SCORE;
    const isAssessedAsBlurry = sharpness < ACCEPTABLE_SHARPNESS_SCORE;
    const { width, height, data } = image;

    /** @type {AcuantImageAssessment} */
    let assessment;
    if (isAssessedAsGlare) {
      setOwnErrorMessage(t('errors.doc_auth.photo_glare'));
      assessment = 'glare';
    } else if (isAssessedAsBlurry) {
      setOwnErrorMessage(t('errors.doc_auth.photo_blurry'));
      assessment = 'blurry';
    } else {
      onChangeAndResetError(data);
      assessment = 'success';
    }

    /** @type {AcuantImageAnalyticsPayload} */
    const analyticsPayload = {
      width,
      height,
      mimeType: 'image/jpeg', // Acuant Web SDK currently encodes all images as JPEG
      source: 'acuant',
      documentType: getDocumentTypeLabel(cardType),
      dpi,
      moire,
      glare,
      glareScoreThreshold: ACCEPTABLE_GLARE_SCORE,
      isAssessedAsGlare,
      sharpness,
      sharpnessScoreThreshold: ACCEPTABLE_SHARPNESS_SCORE,
      isAssessedAsBlurry,
      assessment,
    };

    addPageAction({
      key: 'documentCapture.acuantWebSDKResult',
      label: `IdV: ${name} image added`,
      payload: analyticsPayload,
    });

    setIsCapturingEnvironment(false);
  }

  return (
    <div className={[className, 'document-capture-acuant-capture'].filter(Boolean).join(' ')}>
      {isCapturingEnvironment && (
        <FullScreen onRequestClose={() => setIsCapturingEnvironment(false)}>
          <AcuantCaptureCanvas
            onImageCaptureSuccess={onAcuantImageCaptureSuccess}
            onImageCaptureFailure={(error) => {
              setOwnErrorMessage(t('errors.doc_auth.capture_failure'));
              setIsCapturingEnvironment(false);
              addPageAction({
                label: 'IdV: Image capture failed',
                payload: { field: name, error: getNormalizedAcuantCaptureFailureMessage(error) },
              });
            }}
          />
        </FullScreen>
      )}
      <FileInput
        ref={inputRef}
        label={label}
        hint={hasCapture || !allowUpload ? undefined : t('doc_auth.tips.document_capture_hint')}
        bannerText={bannerText}
        invalidTypeText={t('errors.doc_auth.invalid_file_input_type')}
        fileUpdatedText={t('doc_auth.info.image_updated')}
        accept={isMockClient ? undefined : ['image/jpeg', 'image/png', 'image/bmp', 'image/tiff']}
        capture={capture}
        value={value}
        errorMessage={ownErrorMessage ?? errorMessage}
        onClick={startCaptureOrTriggerUpload}
        onChange={onUpload}
        onError={() => setOwnErrorMessage(null)}
      />
      <div className="margin-top-2">
        {isMobile && (
          <Button
            isFlexibleWidth
            isOutline={!value}
            isUnstyled={!!value}
            onClick={startCaptureOrTriggerUpload}
            className={value ? 'margin-right-1' : 'margin-right-2'}
          >
            {(hasCapture || !allowUpload) &&
              (value
                ? t('doc_auth.buttons.take_picture_retry')
                : t('doc_auth.buttons.take_picture'))}
            {!hasCapture && allowUpload && t('doc_auth.buttons.upload_picture')}
          </Button>
        )}
        {isMobile &&
          hasCapture &&
          allowUpload &&
          formatHTML(t('doc_auth.buttons.take_or_upload_picture'), {
            'lg-take-photo': () => null,
            'lg-upload': ({ children }) => (
              <Button isUnstyled onClick={forceUpload} className="margin-left-1">
                {children}
              </Button>
            ),
          })}
      </div>
    </div>
  );
}

export default forwardRef(AcuantCapture);
