import { useContext, useState } from 'react';
import { hasMediaAccess } from '@18f/identity-device';
import { useI18n } from '@18f/identity-react-i18n';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import { FormStepsContext, FormStepsContinueButton } from '@18f/identity-form-steps';
import DeviceContext from '../context/device';
import DocumentSideAcuantCapture from './document-side-acuant-capture';
import AcuantCapture from './acuant-capture';
import SelfieCapture from './selfie-capture';
import ServiceProviderContext from '../context/service-provider';
import withBackgroundEncryptedUpload from '../higher-order/with-background-encrypted-upload';
import DocumentCaptureTroubleshootingOptions from './document-capture-troubleshooting-options';
import PageHeading from './page-heading';
import StartOverOrCancel from './start-over-or-cancel';
import Warning from './warning';
import AnalyticsContext from '../context/analytics';

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
const DISPLAY_ATTEMPTS = 3;

/**
 * @param {import('@18f/identity-form-steps').FormStepComponentProps<ReviewIssuesStepValue> & {
 *  remainingAttempts: number,
 *  captureHints: boolean,
 * }} props Props object.
 */
function ReviewIssuesStep({
  value = {},
  onChange = () => {},
  errors = [],
  unknownFieldErrors = [],
  onError = () => {},
  registerField = () => undefined,
  remainingAttempts,
  captureHints,
}) {
  const { t } = useI18n();
  const { isMobile } = useContext(DeviceContext);
  const serviceProvider = useContext(ServiceProviderContext);
  const { addPageAction } = useContext(AnalyticsContext);
  const selfieError = errors.find(({ field }) => field === 'selfie')?.error;
  const [hasDismissed, setHasDismissed] = useState(remainingAttempts === Infinity);
  const { onPageTransition } = useContext(FormStepsContext);
  useDidUpdateEffect(onPageTransition, [hasDismissed]);

  function onWarningPageDismissed() {
    addPageAction({ label: 'IdV: Capture troubleshooting dismissed' });

    setHasDismissed(true);
  }

  return hasDismissed ? (
    <>
      <PageHeading>{t('doc_auth.headings.review_issues')}</PageHeading>
      {!!unknownFieldErrors &&
        unknownFieldErrors.map(({ error }) => <p key={error.message}>{error.message}</p>)}
      {captureHints && (
        <>
          <p className="margin-bottom-0">{t('doc_auth.tips.review_issues_id_header_text')}</p>
          <ul>
            <li>{t('doc_auth.tips.review_issues_id_text1')}</li>
            <li>{t('doc_auth.tips.review_issues_id_text2')}</li>
            <li>{t('doc_auth.tips.review_issues_id_text3')}</li>
            <li>{t('doc_auth.tips.review_issues_id_text4')}</li>
          </ul>
        </>
      )}
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
              errorMessage={selfieError?.message}
              name="selfie"
            />
          ) : (
            <SelfieCapture
              ref={registerField('selfie', { isRequired: true })}
              value={value.selfie}
              onChange={(nextSelfie) => onChange({ selfie: nextSelfie })}
              errorMessage={selfieError?.message}
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
      <FormStepsContinueButton />
      <DocumentCaptureTroubleshootingOptions />
      <StartOverOrCancel />
    </>
  ) : (
    <Warning
      heading={t('errors.doc_auth.throttled_heading')}
      actionText={t('idv.failure.button.warning')}
      actionOnClick={onWarningPageDismissed}
      location="doc_auth_review_issues"
      remainingAttempts={remainingAttempts}
      troubleshootingOptions={
        <DocumentCaptureTroubleshootingOptions location="post_submission_warning" />
      }
    >
      {!!unknownFieldErrors &&
        unknownFieldErrors
          .filter((error) => !['front', 'back', 'selfie'].includes(error.field))
          .map(({ error }) => <p key={error.message}>{error.message}</p>)}

      {remainingAttempts <= DISPLAY_ATTEMPTS && (
        <p>
          <strong>
            {remainingAttempts === 1
              ? t('idv.failure.attempts.one')
              : t('idv.failure.attempts.other', { count: remainingAttempts })}
          </strong>
        </p>
      )}
    </Warning>
  );
}

export default withBackgroundEncryptedUpload(ReviewIssuesStep);
