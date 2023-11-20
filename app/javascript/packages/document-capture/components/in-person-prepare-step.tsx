import { useContext } from 'react';
import { Link, PageHeading, ProcessList, ProcessListItem } from '@18f/identity-components';
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
    skipDocAuth,
    howToVerifyURL,
  } = useContext(InPersonContext);

  function goBack() {
    // todo: fix the type error on the next line. We should coerce 'true' to a boolean
    if (skipDocAuth === 'true' && howToVerifyURL) {
      forceRedirect(howToVerifyURL);
    } else {
      toPreviousStep();
    }
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
        <ProcessListItem
          heading={t('in_person_proofing.body.prepare.verify_step_visit_post_office')}
          headingUnstyled
        />
      </ProcessList>
      <p>{t('in_person_proofing.body.prepare.additional_information')}</p>
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
