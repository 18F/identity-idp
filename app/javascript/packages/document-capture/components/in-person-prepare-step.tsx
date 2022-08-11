import {
  Alert,
  Button,
  IconList,
  IconListItem,
  PageHeading,
  ProcessList,
  ProcessListItem,
} from '@18f/identity-components';
import { removeUnloadProtection } from '@18f/identity-url';
import { useContext } from 'react';
import { FlowContext } from '@18f/identity-verify-flow';
import { useI18n } from '@18f/identity-react-i18n';
import { FormStepsButton } from '@18f/identity-form-steps';
import UploadContext from '../context/upload';
import BackButton from './back-button';
import InPersonTroubleshootingOptions from './in-person-troubleshooting-options';

function InPersonPrepareStep({ toPreviousStep, value }) {
  const { t } = useI18n();
  const { inPersonURL } = useContext(FlowContext);
  const { flowPath } = useContext(UploadContext);
  const { selectedLocationName } = value;

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
          title={t('in_person_proofing.body.prepare.bring_proof_header')}
        >
          <p>{t('in_person_proofing.body.prepare.bring_proof_info_acceptable')}</p>
          <ul>
            <li>{t('in_person_proofing.body.prepare.bring_proof_info_lease')}</li>
            <li>{t('in_person_proofing.body.prepare.bring_proof_info_registration')}</li>
            <li>{t('in_person_proofing.body.prepare.bring_proof_info_card')}</li>
            <li>{t('in_person_proofing.body.prepare.bring_proof_info_policy')}</li>
          </ul>
        </IconListItem>
      </IconList>
      {flowPath === 'hybrid' && <FormStepsButton.Continue />}
      {inPersonURL && flowPath === 'standard' && (
        <div className="margin-y-5">
          <Button href={inPersonURL} onClick={removeUnloadProtection} isBig isWide>
            {t('forms.buttons.continue')}
          </Button>
        </div>
      )}
      <InPersonTroubleshootingOptions />
      <BackButton includeBorder onClick={toPreviousStep} />
    </>
  );
}

export default InPersonPrepareStep;
