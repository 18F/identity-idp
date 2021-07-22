import { useContext } from 'react';
import { hasMediaAccess } from '@18f/identity-device';
import useI18n from '../hooks/use-i18n';
import DeviceContext from '../context/device';
import DocumentSideAcuantCapture from './document-side-acuant-capture';
import AcuantCapture from './acuant-capture';
import BlockLink from './block-link';
import SelfieCapture from './selfie-capture';
import FormErrorMessage from './form-error-message';
import ServiceProviderContext from '../context/service-provider';
import withBackgroundEncryptedUpload from '../higher-order/with-background-encrypted-upload';
import './review-issues-step.scss';

/**
 * @typedef {'front'|'back'} DocumentSide
 */

/**
 * @typedef ReviewIssuesStepValue
 *
 * @prop {Blob|string|null|undefined} front Front image value.
 * @prop {Blob|string|null|undefined} back Back image value.
 * @prop {Blob|string|null|undefined} selfie Back image value.
 * @prop {string=} front_image_metadata Front image metadata.
 * @prop {string=} back_image_metadata Back image metadata.
 */

/**
 * Sides of document to present as file input.
 *
 * @type {DocumentSide[]}
 */
const DOCUMENT_SIDES = ['front', 'back'];

/**
 * @param {Partial<ReviewIssuesStepValue>=} value
 *
 * @return {boolean} Whether the value is valid for the review issues step.
 */
function reviewIssuesStepValidator(value = {}) {
  const hasDocuments = DOCUMENT_SIDES.every((side) => !!value[side]);

  // Absent availability of service provider context here, this relies on the fact that:
  // 1) The review step is only shown with an existing, complete set of values.
  // 2) Clearing an existing value sets it as null, but doesn't remove the key from the object.
  const hasSelfieIfApplicable = !('selfie' in value) || !!value.selfie;

  return hasDocuments && hasSelfieIfApplicable;
}

/**
 * @param {import('./form-steps').FormStepComponentProps<ReviewIssuesStepValue>} props Props object.
 */
function ReviewIssuesStep({
  value = {},
  onChange = () => {},
  errors = [],
  onError = () => {},
  registerField = () => undefined,
}) {
  const { t, formatHTML } = useI18n();
  const { isMobile } = useContext(DeviceContext);
  const serviceProvider = useContext(ServiceProviderContext);
  const selfieError = errors.find(({ field }) => field === 'selfie')?.error;

  return (
    <>
      <p className="margin-bottom-0">{t('doc_auth.tips.review_issues_id_header_text')}</p>
      <ul>
        <li>{t('doc_auth.tips.review_issues_id_text1')}</li>
        <li>{t('doc_auth.tips.review_issues_id_text2')}</li>
        <li>{t('doc_auth.tips.review_issues_id_text3')}</li>
        <li>{t('doc_auth.tips.review_issues_id_text4')}</li>
      </ul>
      {DOCUMENT_SIDES.map((side) => (
        <DocumentSideAcuantCapture
          key={side}
          side={side}
          registerField={registerField}
          value={value[side]}
          onChange={onChange}
          errors={errors}
          onError={onError}
          className="document-capture-review-issues-step__input"
        />
      ))}
      {serviceProvider.isLivenessRequired && (
        <>
          <hr className="margin-y-4" />
          <p className="margin-bottom-0">{t('doc_auth.tips.review_issues_selfie_header_text')}</p>
          <ul>
            <li>{t('doc_auth.tips.review_issues_selfie_text1')}</li>
            <li>{t('doc_auth.tips.review_issues_selfie_text2')}</li>
            <li>{t('doc_auth.tips.review_issues_selfie_text3')}</li>
            <li>{t('doc_auth.tips.review_issues_selfie_text4')}</li>
          </ul>
          {isMobile || !hasMediaAccess() ? (
            <AcuantCapture
              ref={registerField('selfie', { isRequired: true })}
              capture="user"
              label={t('doc_auth.headings.document_capture_selfie')}
              bannerText={t('doc_auth.headings.photo')}
              value={value.selfie}
              onChange={(nextSelfie) => onChange({ selfie: nextSelfie })}
              allowUpload={false}
              className="document-capture-review-issues-step__input"
              errorMessage={selfieError ? <FormErrorMessage error={selfieError} /> : undefined}
              name="selfie"
            />
          ) : (
            <SelfieCapture
              ref={registerField('selfie', { isRequired: true })}
              value={value.selfie}
              onChange={(nextSelfie) => onChange({ selfie: nextSelfie })}
              errorMessage={selfieError ? <FormErrorMessage error={selfieError} /> : undefined}
              className={[
                'document-capture-review-issues-step__input',
                !value.selfie && 'document-capture-review-issues-step__input--unconstrained-width',
              ]
                .filter(Boolean)
                .join(' ')}
            />
          )}
        </>
      )}
      {serviceProvider.name && (
        <BlockLink url={serviceProvider.getFailureToProofURL('review_issues_having_trouble')}>
          {formatHTML(t('doc_auth.info.get_help_at_sp_html', { sp_name: serviceProvider.name }), {
            strong: 'strong',
          })}
        </BlockLink>
      )}
    </>
  );
}

export default withBackgroundEncryptedUpload(ReviewIssuesStep);

export { reviewIssuesStepValidator };
