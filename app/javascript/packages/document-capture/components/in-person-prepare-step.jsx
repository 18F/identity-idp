import {
  Alert,
  Icon,
  IconList,
  IconListItem,
  IconListIcon,
  IconListTitle,
  IconListContent,
  PageHeading,
  ProcessList,
  ProcessListItem,
  ProcessListHeading,
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
function InPersonPrepareStep({
  value = {},
  onChange = () => {},
  errors = [],
  registerField = () => undefined,
}) {
  const { t } = useI18n();
  const error = errors.find(({ field }) => field === 'in-person-prepare')?.error;

  return (
    <>
      <Alert type="success" className="margin-bottom-4">
        {t('in_person_proofing.body.prepare.alert_selected_post_office', { name: 'EASTCHESTER' })}
      </Alert>
      <PageHeading>{t('in_person_proofing.headings.prepare')}</PageHeading>

      <p>{t('in_person_proofing.body.prepare.verify_step_about')}</p>

      <ProcessList className="margin-bottom-4">
        <ProcessListItem>
          <ProcessListHeading unstyled>
            {t('in_person_proofing.body.prepare.verify_step_enter_pii')}
          </ProcessListHeading>
        </ProcessListItem>
        <ProcessListItem>
          <ProcessListHeading unstyled>
            {t('in_person_proofing.body.prepare.verify_step_enter_phone')}
          </ProcessListHeading>
        </ProcessListItem>
      </ProcessList>

      <hr className="margin-bottom-4" />

      <h2>{t('in_person_proofing.body.prepare.bring_title')}</h2>

      <IconList>
        <IconListItem>
          <IconListIcon className="text-primary-dark">
            <Icon icon="check_circle" />
          </IconListIcon>
          <IconListContent>
            <IconListTitle className="font-sans-md padding-top-0">
              {t('in_person_proofing.body.prepare.bring_barcode_header')}
            </IconListTitle>
            <p>{t('in_person_proofing.body.prepare.bring_barcode_info')}</p>
          </IconListContent>
        </IconListItem>

        <IconListItem>
          <IconListIcon className="text-primary-dark">
            <Icon icon="check_circle" />
          </IconListIcon>
          <IconListContent>
            <IconListTitle className="font-sans-md padding-top-0">
              {t('in_person_proofing.body.prepare.bring_id_header')}
            </IconListTitle>
            <p>{t('in_person_proofing.body.prepare.bring_id_info_acceptable')}</p>
            <ul>
              <li>{t('in_person_proofing.body.prepare.bring_id_info_dl')}</li>
              <li>{t('in_person_proofing.body.prepare.bring_id_info_id_card')}</li>
            </ul>
            <p>{t('in_person_proofing.body.prepare.bring_id_info_no_other_forms')}</p>
          </IconListContent>
        </IconListItem>

        <IconListItem>
          <IconListIcon className="text-primary-dark">
            <Icon icon="check_circle" />
          </IconListIcon>
          <IconListContent>
            <IconListTitle className="font-sans-md padding-top-0">
              {t('in_person_proofing.body.prepare.bring_proof_header')}
            </IconListTitle>
            <p>{t('in_person_proofing.body.prepare.bring_proof_info_acceptable')}</p>
            <ul>
              <li>{t('in_person_proofing.body.prepare.bring_proof_info_lease')}</li>
              <li>{t('in_person_proofing.body.prepare.bring_proof_info_registration')}</li>
              <li>{t('in_person_proofing.body.prepare.bring_proof_info_card')}</li>
              <li>{t('in_person_proofing.body.prepare.bring_proof_info_policy')}</li>
            </ul>
          </IconListContent>
        </IconListItem>
      </IconList>
      <FormStepsButton.Continue />
      <InPersonTroubleshootingOptions />
    </>
  );
}

export default InPersonPrepareStep;
