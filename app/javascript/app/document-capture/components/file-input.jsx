import React from 'react';
import PropTypes from 'prop-types';
import FileImage from './file-image';
import useInstanceId from '../hooks/use-instance-id';
import useI18n from '../hooks/use-i18n';

/**
 * Returns true if the given file object is an image, or false otherwise.
 *
 * @param {File} file File object to test.
 *
 * @return {boolean} Whether given file is an image.
 */
export function isImageFile(file) {
  return /^image\//.test(file.type);
}

function FileInput({ label, hint, accept, value, onChange }) {
  const t = useI18n();
  const instanceId = useInstanceId();
  const inputId = `file-input-${instanceId}`;
  const hintId = `${inputId}-hint`;

  return (
    <>
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
      <div className="usa-file-input">
        <div className="usa-file-input__target">
          {value && (
            <div className="usa-file-input__preview-heading">
              {t('doc_auth.forms.selected_file')}{' '}
              <span className="usa-file-input__choose">{t('doc_auth.forms.change_file')}</span>
            </div>
          )}
          {value && isImageFile(value) && (
            <div className="usa-file-input__preview" aria-hidden="true">
              <FileImage file={value} alt="" className="usa-file-input__preview__image" />
            </div>
          )}
          {!value && (
            <div className="usa-file-input__instructions" aria-hidden="true">
              <span className="usa-file-input__drag-text">{t('doc_auth.forms.choose_file')}</span>
            </div>
          )}
          <div className="usa-file-input__box" />
          <input
            id={inputId}
            className="usa-file-input__input"
            type="file"
            onChange={(event) => {
              onChange(event.target.files[0]);
            }}
            accept={accept.join()}
            aria-describedby={hint ? hintId : null}
          />
        </div>
      </div>
    </>
  );
}

FileInput.propTypes = {
  label: PropTypes.string.isRequired,
  hint: PropTypes.string,
  accept: PropTypes.arrayOf(PropTypes.string),
  value: PropTypes.instanceOf(window.File),
  onChange: PropTypes.func,
};

FileInput.defaultProps = {
  accept: [],
  hint: null,
  value: undefined,
  onChange: () => {},
};

export default FileInput;
