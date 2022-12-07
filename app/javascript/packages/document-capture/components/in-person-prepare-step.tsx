import { useContext, useState } from 'react';
import type { MouseEventHandler } from 'react';
import {
  Alert,
  Link,
  IconList,
  IconListItem,
  PageHeading,
  ProcessList,
  ProcessListItem,
} from '@18f/identity-components';
import { removeUnloadProtection } from '@18f/identity-url';
import { getConfigValue } from '@18f/identity-config';
import { useI18n } from '@18f/identity-react-i18n';
import { FormStepsButton } from '@18f/identity-form-steps';
import { SpinnerButton } from '@18f/identity-spinner-button';
import UploadContext from '../context/upload';
import MarketingSiteContext from '../context/marketing-site';
import AnalyticsContext from '../context/analytics';
import BackButton from './back-button';
import InPersonTroubleshootingOptions from './in-person-troubleshooting-options';
import { InPersonContext } from '../context';

function InPersonPrepareStep({ toPreviousStep, value }) {
  const { t } = useI18n();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const { inPersonURL } = useContext(InPersonContext);
  const { flowPath } = useContext(UploadContext);
  const { trackEvent } = useContext(AnalyticsContext);
  const { securityAndPrivacyHowItWorksURL } = useContext(MarketingSiteContext);
  const { selectedLocationName } = value;

  const onContinue: MouseEventHandler = async (event) => {
    event.preventDefault();

    if (!isSubmitting) {
      setIsSubmitting(true);
      removeUnloadProtection();
      await trackEvent('IdV: prepare submitted');
      window.location.href = (event.target as HTMLAnchorElement).href;
    }
  };

  return (
    <>
      {selectedLocationName && (
        <Alert type="success" className="margin-bottom-4">
          {t('in_person_proofing.body.prepare.alert_selected_post_office', {
            name: selectedLocationName,
          })}
        </Alert>
      )}
      <PageHeading>{t('in_person_proofing.headings.prepare')}</PageHeading>

      <p>{t('in_person_proofing.body.prepare.verify_step_about')}</p>

      <ProcessList className="margin-bottom-4">
        <ProcessListItem
          heading={t('in_person_proofing.body.prepare.verify_step_enter_pii')}
          headingUnstyled
        />
        <ProcessListItem
          heading={t('in_person_proofing.body.prepare.verify_step_enter_phone')}
          headingUnstyled
        />
      </ProcessList>

      <hr className="margin-bottom-4" />

      <h2>{t('in_person_proofing.body.prepare.bring_title')}</h2>

      <IconList>
        <IconListItem
          icon="check_circle"
          title={t('in_person_proofing.body.prepare.bring_barcode_header')}
        >
          <p>{t('in_person_proofing.body.prepare.bring_barcode_info')}</p>
        </IconListItem>

        <IconListItem
          icon="check_circle"
          title={t('in_person_proofing.body.prepare.bring_id_header')}
        >
          <p>{t('in_person_proofing.body.prepare.bring_id_info_acceptable')}</p>
          <ul>
            <li>{t('in_person_proofing.body.prepare.bring_id_info_dl')}</li>
            <li>{t('in_person_proofing.body.prepare.bring_id_info_id_card')}</li>
          </ul>
          <p>{t('in_person_proofing.body.prepare.bring_id_info_no_other_forms')}</p>
        </IconListItem>

        <IconListItem
          icon="check_circle"
          title={t('in_person_proofing.process.proof_of_address.heading')}
        >
          <p>{t('in_person_proofing.process.proof_of_address.info')}</p>
          <ul>
            {t(['in_person_proofing.process.proof_of_address.acceptable_proof']).map((proof) => (
              <li key={proof}>{proof}</li>
            ))}
          </ul>
          <p>{t('in_person_proofing.process.proof_of_address.physical_or_digital_copy')}</p>
        </IconListItem>
      </IconList>
      {flowPath === 'hybrid' && <FormStepsButton.Continue />}
      {inPersonURL && flowPath === 'standard' && (
        <div className="margin-y-5">
          <SpinnerButton href={inPersonURL} onClick={onContinue} isBig isWide>
            {t('forms.buttons.continue')}
          </SpinnerButton>
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
      <BackButton includeBorder onClick={toPreviousStep} />
    </>
  );
}

export default InPersonPrepareStep;
