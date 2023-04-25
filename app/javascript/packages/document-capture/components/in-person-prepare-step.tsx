import { useContext, useState } from 'react';
import type { MouseEventHandler } from 'react';
import { Button, Link, PageHeading, ProcessList, ProcessListItem } from '@18f/identity-components';
import { getConfigValue } from '@18f/identity-config';
import { useI18n } from '@18f/identity-react-i18n';
import { FormStepsButton } from '@18f/identity-form-steps';
import useHistoryParam from '@18f/identity-form-steps/use-history-param';
import UploadContext from '../context/upload';
import MarketingSiteContext from '../context/marketing-site';
import AnalyticsContext from '../context/analytics';
import BackButton from './back-button';
import InPersonTroubleshootingOptions from './in-person-troubleshooting-options';
import { InPersonContext } from '../context';

function InPersonPrepareStep({ toPreviousStep }) {
  const { t } = useI18n();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [, setStepName] = useHistoryParam(undefined);
  const { inPersonURL, inPersonCtaVariantActive } = useContext(InPersonContext);
  const { flowPath } = useContext(UploadContext);
  const { trackEvent, setSubmitEventMetadata } = useContext(AnalyticsContext);
  const { securityAndPrivacyHowItWorksURL } = useContext(MarketingSiteContext);

  const onContinue: MouseEventHandler = (event: React.MouseEvent) => {
    event.preventDefault();

    if (!isSubmitting) {
      setIsSubmitting(true);
      setSubmitEventMetadata({ in_person_cta_variant: inPersonCtaVariantActive });
      trackEvent('IdV: prepare submitted');
      setStepName('location');
    }
  };

  return (
    <>
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
      {flowPath === 'hybrid' && <FormStepsButton.Continue />}
      {inPersonURL && flowPath === 'standard' && (
        <div className="margin-y-5">
          <Button
            isBig
            isWide
            className="margin-top-3 margin-bottom-1"
            onClick={(event: React.MouseEvent) => onContinue(event)}
          >
            {t('forms.buttons.continue')}
          </Button>
        </div>
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
      <BackButton role="link" includeBorder onClick={toPreviousStep} />
    </>
  );
}

export default InPersonPrepareStep;
