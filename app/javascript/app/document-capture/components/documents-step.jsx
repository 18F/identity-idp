import React from 'react';
import PropTypes from 'prop-types';
import FileInput from './file-input';
import useI18n from '../hooks/use-i18n';

/**
 * Sides of document to present as file input.
 *
 * @type {string[]}
 */
const DOCUMENT_SIDES = ['front', 'back'];

function DocumentsStep({ value, onChange }) {
  const t = useI18n();

  return (
    <>
      {DOCUMENT_SIDES.map((side) => {
        const label = t(`doc_auth.headings.upload_${side}`);
        const inputKey = `${side}_image`;

        return (
          <FileInput
            key={side}
            label={label}
            accept={['image/*']}
            value={value[inputKey]}
            onChange={(nextValue) => onChange({ [inputKey]: nextValue })}
          />
        );
      })}
    </>
  );
}

DocumentsStep.propTypes = {
  value: PropTypes.shape({
    upload_front: PropTypes.string,
    upload_back: PropTypes.string,
  }),
  onChange: PropTypes.func,
};

DocumentsStep.defaultProps = {
  value: {},
  onChange: () => {},
};

/**
 * Returns true if the step is valid for the given values, or false otherwise.
 *
 * @param {Record<string,string>} value Current form values.
 *
 * @return {boolean} Whether step is valid.
 */
export const isValid = (value) => Boolean(value.front_image && value.back_image);

export default DocumentsStep;
