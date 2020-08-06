import React, { useContext, useState } from 'react';
import PropTypes from 'prop-types';
import DeviceContext from '../context/device';
import useInstanceId from '../hooks/use-instance-id';
import useIfStillMounted from '../hooks/use-if-still-mounted';
import useI18n from '../hooks/use-i18n';
import DataURLFile from '../models/data-url-file';

/**
 * Returns true if the given data URL represents an image, or false otherwise.
 *
 * @param {string} dataURL File data URL to test.
 *
 * @return {boolean} Whether given data URL is an image.
 */
export function isImage(dataURL) {
  return /^data:image\//.test(dataURL);
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

function FileInput({ label, hint, bannerText, accept, value, onChange, className }) {
  const { t, formatHTML } = useI18n();
  const ifStillMounted = useIfStillMounted();
  const instanceId = useInstanceId();
  const { isMobile } = useContext(DeviceContext);
  const [isDraggingOver, setIsDraggingOver] = useState(false);
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
    toDataURL(file).then(ifStillMounted((data) => onChange(new DataURLFile(data, file.name))));
  }

  return (
    <div className={className}>
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
      <label htmlFor={inputId} className="usa-label">
        {label}
      </label>
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
                    // eslint-disable-next-line react/prop-types
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
            id={inputId}
            className="usa-file-input__input"
            type="file"
            onChange={onChangeAsDataURL}
            accept={accept.join()}
            aria-describedby={hint ? hintId : null}
          />
        </div>
      </div>
    </div>
  );
}

FileInput.propTypes = {
  label: PropTypes.string.isRequired,
  hint: PropTypes.string,
  bannerText: PropTypes.string,
  accept: PropTypes.arrayOf(PropTypes.string),
  value: PropTypes.instanceOf(DataURLFile),
  onChange: PropTypes.func,
  className: PropTypes.string,
};

FileInput.defaultProps = {
  hint: null,
  bannerText: null,
  accept: [],
  value: undefined,
  onChange: () => {},
  className: null,
};

export default FileInput;
