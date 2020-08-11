import React, { useContext } from 'react';
import AcuantCapture from './acuant-capture';
import useI18n from '../hooks/use-i18n';
import DeviceContext from '../context/device';

/** @typedef {import('../models/data-url-file')} DataURLFile */

/**
 * @typedef DocumentsStepValue
 *
 * @prop {DataURLFile=} front_image Front image value.
 * @prop {DataURLFile=} back_image  Back image value.
 */

/**
 * @typedef DocumentsStepProps
 *
 * @prop {DocumentsStepValue=}                            value Current value.
 * @prop {(nextValue:Partial<DocumentsStepValue>)=>void=} onChange Value change handler.
 */

/**
 * Sides of document to present as file input.
 *
 * @type {string[]}
 */
const DOCUMENT_SIDES = ['front', 'back'];

/**
 * @param {DocumentsStepProps} props Props object.
 */
function DocumentsStep({ value = {}, onChange = () => {} }) {
  const { t } = useI18n();
  const { isMobile } = useContext(DeviceContext);

  return (
    <>
      <p className="margin-top-2 margin-bottom-0">
        {t('doc_auth.tips.document_capture_header_text')}
      </p>
      <ul>
        <li>{t('doc_auth.tips.document_capture_id_text1')}</li>
        <li>{t('doc_auth.tips.document_capture_id_text2')}</li>
        <li>{t('doc_auth.tips.document_capture_id_text3')}</li>
        {!isMobile && <li>{t('doc_auth.tips.document_capture_id_text4')}</li>}
      </ul>
      {DOCUMENT_SIDES.map((side) => {
        const inputKey = `${side}_image`;

        return (
          <AcuantCapture
            key={side}
            /* i18n-tasks-use t('doc_auth.headings.document_capture_back') */
            /* i18n-tasks-use t('doc_auth.headings.document_capture_front') */
            label={t(`doc_auth.headings.document_capture_${side}`)}
            /* i18n-tasks-use t('doc_auth.headings.back') */
            /* i18n-tasks-use t('doc_auth.headings.front') */
            bannerText={t(`doc_auth.headings.${side}`)}
            value={value[inputKey]}
            onChange={(nextValue) => onChange({ [inputKey]: nextValue })}
            className="id-card-file-input"
          />
        );
      })}
    </>
  );
}

/**
 * Returns true if the step is valid for the given values, or false otherwise.
 *
 * @param {Record<string,string>} value Current form values.
 *
 * @return {boolean} Whether step is valid.
 */
export const isValid = (value) => Boolean(value.front_image && value.back_image);

export default DocumentsStep;
