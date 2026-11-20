import { useContext } from 'react';
import { Button, Link, PageHeading, ProcessList, ProcessListItem } from '@18f/identity-components';
import { getConfigValue } from '@18f/identity-config';
import { useI18n } from '@18f/identity-react-i18n';
import { FormStepsButton } from '@18f/identity-form-steps';
import { forceRedirect } from '@18f/identity-url';
import UploadContext from '../context/upload';
import MarketingSiteContext from '../context/marketing-site';
import BackButton from './back-button';
import InPersonTroubleshootingOptions from './in-person-troubleshooting-options';
import { InPersonContext } from '../context';
import InPersonOutageAlert from './in-person-outage-alert';

function InPersonPrepareStep({ toPreviousStep }) {
  const { t } = useI18n();
  const { flowPath } = useContext(UploadContext);
  const { securityAndPrivacyHowItWorksURL } = useContext(MarketingSiteContext);
  const {
    inPersonURL,
    inPersonOutageMessageEnabled,
    inPersonOutageExpectedUpdateDate,
    skipDocAuthFromHowToVerify,
    skipDocAuthFromHandoff,
    skipDocAuthFromSocure,
    howToVerifyURL,
    socureErrorsTimeoutURL,
    previousStepURL,
    ndsLayout,
  } = useContext(InPersonContext);

  function goBack() {
    if (skipDocAuthFromHandoff && previousStepURL) {
      // directly from handoff page
      forceRedirect(previousStepURL);
    } else if (skipDocAuthFromHowToVerify && howToVerifyURL) {
      forceRedirect(howToVerifyURL);
    } else if (skipDocAuthFromSocure && socureErrorsTimeoutURL) {
      // directly from Socure Hybrid page
      forceRedirect(socureErrorsTimeoutURL);
    } else {
      toPreviousStep();
    }
  }

  if (ndsLayout) {
    return (
      <section className="auth auth--form-page">
        {inPersonOutageMessageEnabled && inPersonOutageExpectedUpdateDate && (
          <InPersonOutageAlert />
        )}
        <div className="auth__header">
          <div className="stack stack--align-center auth__intro">
            <h1>{t('in_person_proofing.headings.prepare')}</h1>
            <div className="auth__intro-description">{t('nds.post_office.prepare.intro')}</div>
          </div>
        </div>
        <hr className="divider" />
        <ol className="list stack stack--gap-16 copy--muted">
          <li>{t('in_person_proofing.body.prepare.verify_step_post_office')}</li>
          <li>{t('nds.post_office.prepare.step_details')}</li>
          <li>{t('nds.post_office.prepare.step_phone')}</li>
        </ol>
        <div className="auth__actions">
          <div className="actions actions--align-stretch">
            <Button type="submit" className="usa-button--lg">
              {t('forms.buttons.continue')}
            </Button>
            <Button role="link" className="usa-button--tertiary usa-button--lg" onClick={goBack}>
              {t('forms.buttons.back')}
            </Button>
          </div>
        </div>
      </section>
    );
  }

  return (
    <>
      {inPersonOutageMessageEnabled && inPersonOutageExpectedUpdateDate && <InPersonOutageAlert />}

      <PageHeading>{t('in_person_proofing.headings.prepare')}</PageHeading>

      <p>{t('in_person_proofing.body.prepare.verify_step_about')}</p>

      <ProcessList className="margin-bottom-4">
        <ProcessListItem
          heading={t('in_person_proofing.body.prepare.verify_step_post_office')}
          headingUnstyled
        />
        <ProcessListItem
          heading={t('in_person_proofing.body.prepare.verify_step_enter_pii')}
          headingUnstyled
        />
        <ProcessListItem
          heading={t('in_person_proofing.body.prepare.verify_step_enter_phone')}
          headingUnstyled
        />
      </ProcessList>
      {inPersonURL && flowPath === 'standard' ? (
        <FormStepsButton.Continue className="margin-y-5" />
      ) : (
        <FormStepsButton.Continue />
      )}
      <p>
        {t('in_person_proofing.body.prepare.privacy_disclaimer', {
          app_name: getConfigValue('appName'),
        })}{' '}
        {securityAndPrivacyHowItWorksURL && (
          <>
            {t('in_person_proofing.body.prepare.privacy_disclaimer_questions')}{' '}
            <Link href={securityAndPrivacyHowItWorksURL}>
              {t('in_person_proofing.body.prepare.privacy_disclaimer_link')}
            </Link>
          </>
        )}
      </p>
      <InPersonTroubleshootingOptions />
      <BackButton role="link" includeBorder onClick={goBack} />
    </>
  );
}

export default InPersonPrepareStep;
