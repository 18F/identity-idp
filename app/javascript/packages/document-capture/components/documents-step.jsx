import { useContext } from 'react';
import AcuantCapture from './acuant-capture';
import FormErrorMessage from './form-error-message';
import useI18n from '../hooks/use-i18n';
import DeviceContext from '../context/device';
import withBackgroundEncryptedUpload from '../higher-order/with-background-encrypted-upload';

/**
 * @typedef DocumentsStepValue
 *
 * @prop {Blob|string|null|undefined} front Front image value.
 * @prop {Blob|string|null|undefined} back Back image value.
 */

/**
 * Sides of document to present as file input.
 *
 * @type {Array<keyof DocumentsStepValue>}
 */
const DOCUMENT_SIDES = ['front', 'back'];

/**
 * @return {Boolean} whether or not the value is valid for the document step
 */
function documentsStepValidator(value = {}) {
  return DOCUMENT_SIDES.every((side) => !!value[side]);
}

/**
 * @param {import('./form-steps').FormStepComponentProps<DocumentsStepValue>} props Props object.
 */
function DocumentsStep({
  value = {},
  onChange = () => {},
  errors = [],
  registerField = () => undefined,
}) {
  const { t } = useI18n();
  const { isMobile } = useContext(DeviceContext);

  return (
    <>
      <p className="margin-bottom-0">{t('doc_auth.tips.document_capture_header_text')}</p>
      <ul>
        <li>{t('doc_auth.tips.document_capture_id_text1')}</li>
        <li>{t('doc_auth.tips.document_capture_id_text2')}</li>
        <li>{t('doc_auth.tips.document_capture_id_text3')}</li>
        {!isMobile && <li>{t('doc_auth.tips.document_capture_id_text4')}</li>}
      </ul>
      {DOCUMENT_SIDES.map((side) => {
        const error = errors.find(({ field }) => field === side)?.error;

        return (
          <AcuantCapture
            key={side}
            ref={registerField(side, { isRequired: true })}
            /* i18n-tasks-use t('doc_auth.headings.document_capture_back') */
            /* i18n-tasks-use t('doc_auth.headings.document_capture_front') */
            label={t(`doc_auth.headings.document_capture_${side}`)}
            /* i18n-tasks-use t('doc_auth.headings.back') */
            /* i18n-tasks-use t('doc_auth.headings.front') */
            bannerText={t(`doc_auth.headings.${side}`)}
            value={value[side]}
            onChange={(nextValue) => onChange({ [side]: nextValue })}
            errorMessage={error ? <FormErrorMessage error={error} /> : undefined}
          />
        );
      })}
    </>
  );
}

const DocumentsStepWithBackgroundUpload = withBackgroundEncryptedUpload(DocumentsStep);

export {
  DocumentsStepWithBackgroundUpload as DocumentsStep,
  documentsStepValidator
};
