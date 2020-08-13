import React, { useContext, useState, useMemo, forwardRef } from 'react';
import DeviceContext from '../context/device';
import useInstanceId from '../hooks/use-instance-id';
import useIfStillMounted from '../hooks/use-if-still-mounted';
import useI18n from '../hooks/use-i18n';
import DataURLFile from '../models/data-url-file';

/** @typedef {import('react').MouseEvent} ReactMouseEvent */
/** @typedef {import('react').ChangeEvent} ReactChangeEvent */
/** @typedef {import('react').RefAttributes} ReactRefAttributes */

/**
 * @typedef FileInputProps
 *
 * @prop {string}                          label      Input label.
 * @prop {string=}                         hint       Optional hint text.
 * @prop {string=}                         bannerText Optional banner overlay text.
 * @prop {string[]=}                       accept     Optional array of file input accept patterns.
 * @prop {DataURLFile=}                    value      Current value.
 * @prop {string=}                         error      Error to show.
 * @prop {(event:ReactMouseEvent)=>void=}  onClick    Input click handler.
 * @prop {(nextValue:DataURLFile?)=>void=} onChange   Input change handler.
 * @prop {(message:string)=>void=}         onError    Callback to trigger if upload error occurs.
 */

/**
 * Given a data URL string, returns the MIME type.
 *
 * @see https://tools.ietf.org/html/rfc2397#section-3
 *
 * @param {string} dataURL Data URL.
 *
 * @return {string} MIME type.
 */
export function getDataURLMimeType(dataURL) {
  const [mimeType] = dataURL.replace(/^data:/, '').split(/[;,]/);
  return mimeType || 'text/plain';
}

/**
 * Given a token of an file input accept attribute, returns an equivalent regular expression
 * pattern, or undefined if a pattern cannot be determined. This is an approximation, and not fully
 * spec-compliant to allowable characters in what is considered a valid MIME type.
 *
 * @see https://html.spec.whatwg.org/multipage/input.html#attr-input-accept
 * @see https://tools.ietf.org/html/rfc7231#section-3.1.1.1
 * @see https://tools.ietf.org/html/rfc2045#section-5.1
 *
 * @param {string} accept Accept token.
 *
 * @return {RegExp=} Regular expression, or undefined if cannot be determined.
 */
export function getAcceptPattern(accept) {
  switch (accept) {
    case 'audio/*':
    case 'video/*':
    case 'image/*': {
      const [type] = accept.split('/');
      return new RegExp(`^${type}/.+`);
    }

    default:
      return /^[\w-]+\/[\w-]+$/.test(accept) ? new RegExp(`^${accept}$`) : undefined;
  }
}

/**
 * Returns true if the given data URL represents an image, or false otherwise.
 *
 * @param {string} dataURL File data URL to test.
 *
 * @return {boolean} Whether given data URL is an image.
 */
export function isImage(dataURL) {
  return getAcceptPattern('image/*').test(getDataURLMimeType(dataURL));
}

/**
 * Returns true if the given MIME type is valid for the array of accept tokens or if the accept
 * parameter is empty. Returns false otherwise.
 *
 * @param {string}    mimeType MIME type to test.
 * @param {?string[]} accept   Accept tokens.
 *
 * @return {boolean} Whether data URL is valid.
 */
export function isValidForAccepts(mimeType, accept) {
  return (
    !accept || accept.map(getAcceptPattern).some((pattern) => pattern && pattern.test(mimeType))
  );
}

/**
 * Returns a promise resolving to the data URL representation of the given file.
 *
 * @param {File} file File to convert.
 *
 * @return {Promise<string>} Promise resolving to data URL.
 */
export function toDataURL(file) {
  return new Promise((resolve, reject) => {
    const reader = new window.FileReader();
    reader.addEventListener('load', () => resolve(/** @type {string} */ (reader.result)));
    reader.addEventListener('error', reject);
    reader.readAsDataURL(file);
  });
}

/**
 * @type {import('react').ForwardRefExoticComponent<FileInputProps & ReactRefAttributes>}
 */
const FileInput = forwardRef((props, ref) => {
  const {
    label,
    hint,
    bannerText,
    accept,
    value,
    error,
    onClick = () => {},
    onChange = () => {},
    onError = () => {},
  } = props;
  const { t, formatHTML } = useI18n();
  const ifStillMounted = useIfStillMounted();
  const instanceId = useInstanceId();
  const { isMobile } = useContext(DeviceContext);
  const [isDraggingOver, setIsDraggingOver] = useState(false);
  const [ownError, setOwnError] = useState(/** @type {string?} */ null);
  useMemo(() => setOwnError(null), [value]);
  const inputId = `file-input-${instanceId}`;
  const hintId = `${inputId}-hint`;

  /**
   * In response to a file input change event, converts the assigned file to a data URL before
   * calling `onChange`.
   *
   * @param {import('react').ChangeEvent<HTMLInputElement>} event Change event.
   */
  function onChangeAsDataURL(event) {
    const file = event.target.files[0];
    if (file) {
      if (isValidForAccepts(file.type, accept)) {
        toDataURL(file).then(ifStillMounted((data) => onChange(new DataURLFile(data, file.name))));
      } else {
        const nextOwnError = t('errors.doc_auth.selfie');
        setOwnError(nextOwnError);
        onError(nextOwnError);
      }
    } else {
      onChange(null);
    }
  }

  const shownError = error ?? ownError;

  return (
    <div
      className={[shownError && 'usa-form-group usa-form-group--error'].filter(Boolean).join(' ')}
    >
      {/*
       * Disable reason: The Airbnb configuration of the `jsx-a11y` rule is strict in that it
       * requires _both_ the `for` attribute and nesting, to maximize support for assistive
       * technology. By the standard, only one or the other should be required. A form layout which
       * includes a hint following a label cannot be nested within the label without misidentifying
       * the hint as part of the label, which is the markup currently supported by USWDS.
       *
       * See: https://github.com/jsx-eslint/eslint-plugin-jsx-a11y/issues/718
       * See: https://github.com/airbnb/javascript/pull/2136
       */}
      {/* eslint-disable-next-line jsx-a11y/label-has-associated-control */}
      <label
        htmlFor={inputId}
        className={['usa-label', shownError && 'usa-label--error'].filter(Boolean).join(' ')}
      >
        {label}
      </label>
      {shownError && (
        <span className="usa-error-message" role="alert">
          {shownError}
        </span>
      )}
      {hint && (
        <span className="usa-hint" id={hintId}>
          {hint}
        </span>
      )}
      <div
        className={[
          'usa-file-input usa-file-input--single-value',
          isDraggingOver && 'usa-file-input--drag',
          value && 'usa-file-input--has-value',
        ]
          .filter(Boolean)
          .join(' ')}
        onDragOver={() => setIsDraggingOver(true)}
        onDragLeave={() => setIsDraggingOver(false)}
        onDrop={() => setIsDraggingOver(false)}
      >
        <div className="usa-file-input__target">
          {value && !isMobile && (
            <div className="usa-file-input__preview-heading">
              <span>
                {value.name && (
                  <>
                    <span className="usa-sr-only">{t('doc_auth.forms.selected_file')}: </span>
                    {value.name}{' '}
                  </>
                )}
              </span>
              <span className="usa-file-input__choose">{t('doc_auth.forms.change_file')}</span>
            </div>
          )}
          {value && isImage(value.data) && (
            <div className="usa-file-input__preview" aria-hidden="true">
              <img src={value.data} alt="" className="usa-file-input__preview__image" />
            </div>
          )}
          {!value && (
            <div className="usa-file-input__instructions" aria-hidden="true">
              {bannerText && <strong className="usa-file-input__banner-text">{bannerText}</strong>}
              {isMobile && bannerText ? null : (
                <span className="usa-file-input__drag-text">
                  {formatHTML(t('doc_auth.forms.choose_file_html'), {
                    'lg-underline': ({ children }) => (
                      <span className="usa-file-input__choose">{children}</span>
                    ),
                  })}
                </span>
              )}
            </div>
          )}
          <div className="usa-file-input__box" />
          <input
            ref={ref}
            id={inputId}
            className="usa-file-input__input"
            type="file"
            onChange={onChangeAsDataURL}
            onClick={onClick}
            accept={accept ? accept.join() : undefined}
            aria-describedby={hint ? hintId : null}
          />
        </div>
      </div>
    </div>
  );
});

export default FileInput;
