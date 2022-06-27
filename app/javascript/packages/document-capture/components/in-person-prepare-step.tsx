import {
  Alert,
  IconList,
  IconListItem,
  PageHeading,
  ProcessList,
  ProcessListItem,
} from '@18f/identity-components';
import { FormStepsButton } from '@18f/identity-form-steps';
import { useI18n } from '@18f/identity-react-i18n';
import InPersonTroubleshootingOptions from './in-person-troubleshooting-options';

/**
 * @typedef InPersonPrepareStepValue
 *
 * @prop {Blob|string|null|undefined} inPersonPrepare InPersonPrepare value.
 */

/**
 * @param {import('@18f/identity-form-steps').FormStepComponentProps<InPersonPrepareValue>} props Props object.
 */
function InPersonPrepareStep() {
  const { t } = useI18n();

  return (
    <>
      <Alert type="success" className="margin-bottom-4">
        {t('in_person_proofing.body.prepare.alert_selected_post_office', { name: 'EASTCHESTER' })}
      </Alert>
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
      <FormStepsButton.Continue />
      <InPersonTroubleshootingOptions />
    </>
  );
}

export default InPersonPrepareStep;
