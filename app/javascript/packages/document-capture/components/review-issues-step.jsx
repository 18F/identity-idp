import React, { useContext } from 'react';
import { hasMediaAccess } from '@18f/identity-device';
import useI18n from '../hooks/use-i18n';
import DeviceContext from '../context/device';
import AcuantCapture from './acuant-capture';
import SelfieCapture from './selfie-capture';
import FormErrorMessage from './form-error-message';
import ServiceProviderContext from '../context/service-provider';
import './review-issues-step.scss';

/**
 * @typedef ReviewIssuesStepValue
 *
 * @prop {Blob|string|null|undefined} front Front image value.
 * @prop {Blob|string|null|undefined} back Back image value.
 * @prop {Blob|string|null|undefined} selfie Back image value.
 */

/**
 * Sides of document to present as file input.
 */
const DOCUMENT_SIDES = ['front', 'back'];

/**
 * @param {import('./form-steps').FormStepComponentProps<ReviewIssuesStepValue>} props Props object.
 */
function ReviewIssuesStep({
  value = {},
  onChange = () => {},
  errors = [],
  registerField = () => undefined,
}) {
  const { t, formatHTML } = useI18n();
  const { isMobile } = useContext(DeviceContext);
  const serviceProvider = useContext(ServiceProviderContext);
  const selfieError = errors.find(({ field }) => field === 'selfie')?.error;

  return (
    <>
      <p>
        {formatHTML(t('doc_auth.info.id_worn_html'), {
          strong: 'strong',
        })}
      </p>
      {serviceProvider.name && (
        <p>
          {formatHTML(
            t('doc_auth.info.no_other_id_help_bold_html', { sp_name: serviceProvider.name }),
            {
              strong: ({ children }) => <>{children}</>,
              a: ({ children }) =>
                serviceProvider.failureToProofURL ? (
                  <a href={serviceProvider.failureToProofURL}>{children}</a>
                ) : (
                  <>{children}</>
                ),
            },
          )}
        </p>
      )}
      <p className="margin-bottom-0">{t('doc_auth.tips.review_issues_id_header_text')}</p>
      <ul>
        <li>{t('doc_auth.tips.review_issues_id_text1')}</li>
        <li>{t('doc_auth.tips.review_issues_id_text2')}</li>
        <li>{t('doc_auth.tips.review_issues_id_text3')}</li>
        <li>{t('doc_auth.tips.review_issues_id_text4')}</li>
      </ul>
      {DOCUMENT_SIDES.map((side) => {
        const sideError = errors.find(({ field }) => field === side)?.error;

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
            className="id-card-file-input document-capture-review-issues-step__input"
            errorMessage={sideError ? <FormErrorMessage error={sideError} /> : undefined}
          />
        );
      })}
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
              className="id-card-file-input document-capture-review-issues-step__input"
              errorMessage={selfieError ? <FormErrorMessage error={selfieError} /> : undefined}
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
    </>
  );
}

export default ReviewIssuesStep;
