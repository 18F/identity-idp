import React, { useContext, useRef, useState, useMemo } from 'react';
import AcuantContext from '../context/acuant';
import AcuantCaptureCanvas from './acuant-capture-canvas';
import FileInput from './file-input';
import FullScreen from './full-screen';
import Button from './button';
import useI18n from '../hooks/use-i18n';
import DeviceContext from '../context/device';
import DataURLFile from '../models/data-url-file';

/**
 * @typedef AcuantCaptureProps
 *
 * @prop {string}                        label      Label associated with file input.
 * @prop {string=}                       bannerText Optional banner text to show in file input.
 * @prop {DataURLFile=}                  value      Current value.
 * @prop {(nextValue:DataURLFile)=>void} onChange   Callback receiving next value on change.
 * @prop {string=}                       className  Optional additional class names.
 */

/**
 * The minimum glare score value to be considered acceptable.
 *
 * @type {number}
 */
const ACCEPTABLE_GLARE_SCORE = 50;

/**
 * The minimum sharpness score value to be considered acceptable.
 *
 * @type {number}
 */
const ACCEPTABLE_SHARPNESS_SCORE = 50;

/**
 * Returns an element serving as an enhanced FileInput, supporting direct capture using Acuant SDK
 * in supported devices.
 *
 * @param {AcuantCaptureProps} props Props object.
 */
function AcuantCapture({ label, bannerText, value, onChange = () => {}, className }) {
  const { isReady, isError, isCameraSupported } = useContext(AcuantContext);
  const inputRef = useRef(/** @type {?HTMLElement} */ (null));
  const isForceUploading = useRef(false);
  const [isCapturing, setIsCapturing] = useState(false);
  const [ownError, setOwnError] = useState(/** @type {?string} */ (null));
  useMemo(() => setOwnError(null), [value]);
  const { isMobile } = useContext(DeviceContext);
  const { t, formatHTML } = useI18n();
  const hasCapture = !isError && (isReady ? isCameraSupported : isMobile);

  /**
   * Responds to a click by starting capture if supported in the environment, or triggering the
   * default file picker prompt. The click event may originate from the file input itself, or
   * another element which aims to trigger the prompt of the file input.
   *
   * @param {import('react').MouseEvent} event Click event.
   */
  function startCaptureOrTriggerUpload(event) {
    if (hasCapture) {
      if (!isForceUploading.current) {
        event.preventDefault();
        setIsCapturing(true);
      }

      isForceUploading.current = false;
    } else if (event.target !== inputRef.current) {
      inputRef.current.click();
    }
  }

  /**
   * Triggers upload to occur, regardless of support for direct capture. This is necessary since the
   * default behavior for interacting with the file input is intercepted when capture is supported.
   * Calling `forceUpload` will flag the click handling to skip intercepting the event as capture.
   */
  function forceUpload() {
    isForceUploading.current = true;
    inputRef.current.click();
  }

  return (
    <div className={className}>
      {isCapturing && (
        <FullScreen onRequestClose={() => setIsCapturing(false)}>
          <AcuantCaptureCanvas
            onImageCaptureSuccess={(nextCapture) => {
              if (nextCapture.glare < ACCEPTABLE_GLARE_SCORE) {
                setOwnError(t('errors.doc_auth.photo_glare'));
              } else if (nextCapture.sharpness < ACCEPTABLE_SHARPNESS_SCORE) {
                setOwnError(t('errors.doc_auth.photo_blurry'));
              } else {
                onChange(new DataURLFile(nextCapture.image.data));
              }

              setIsCapturing(false);
            }}
            onImageCaptureFailure={() => setIsCapturing(false)}
          />
        </FullScreen>
      )}
      <FileInput
        ref={inputRef}
        label={label}
        hint={hasCapture ? undefined : t('doc_auth.tips.document_capture_hint')}
        bannerText={bannerText}
        accept={['image/*']}
        value={value}
        error={ownError}
        onClick={startCaptureOrTriggerUpload}
        onChange={onChange}
      />
      <div className="margin-top-2">
        {isMobile && (
          <Button
            isSecondary={!value}
            isUnstyled={!!value}
            onClick={startCaptureOrTriggerUpload}
            className={value ? 'margin-right-1' : 'margin-right-2'}
          >
            {hasCapture &&
              (value
                ? t('doc_auth.buttons.take_picture_retry')
                : t('doc_auth.buttons.take_picture'))}
            {!hasCapture && t('doc_auth.buttons.upload_picture')}
          </Button>
        )}
        {isMobile &&
          hasCapture &&
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

export default AcuantCapture;
