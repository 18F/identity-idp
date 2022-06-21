import { useContext } from 'react';
import { hasMediaAccess } from '@18f/identity-device';
import { useI18n } from '@18f/identity-react-i18n';
import { FormStepsButton } from '@18f/identity-form-steps';
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
import DeviceContext from '../context/device';
import StartOverOrCancel from './start-over-or-cancel';

/**
 * @typedef WelcomeStepValue
 *
 * @prop {Blob|string|null|undefined} welcome Welcome value.
 */

/**
 * @param {import('@18f/identity-form-steps').FormStepComponentProps<WelcomeStepValue>} props Props object.
 */
function WelcomeStep({
  value = {},
  onChange = () => {},
  errors = [],
  registerField = () => undefined,
}) {
  const { t } = useI18n();
  const error = errors.find(({ field }) => field === 'welcome')?.error;

  return (
    <>
      <Alert type="success" className="margin-bottom-4">
        {t('in_person_proofing.body.welcome.alert_selected_post_office', { name: 'EASTCHESTER' })}
      </Alert>
      <PageHeading>{t('in_person_proofing.headings.welcome')}</PageHeading>

      <p>{t('in_person_proofing.body.welcome.verify_step_about')}</p>

      <ProcessList>
        <ProcessListItem>
          <ProcessListHeading unstyled>
            {t('in_person_proofing.body.welcome.verify_step_enter_pii')}
          </ProcessListHeading>
        </ProcessListItem>
        <ProcessListItem>
          <ProcessListHeading unstyled>
            {t('in_person_proofing.body.welcome.verify_step_enter_phone')}
          </ProcessListHeading>
        </ProcessListItem>
      </ProcessList>

      <hr />

      <h2>{t('in_person_proofing.body.welcome.bring_title')}</h2>

      <IconList>
        <IconListItem>
          <IconListIcon className="text-indigo">
            <Icon icon="check_circle" />
          </IconListIcon>
          <IconListContent>
            <IconListTitle>
              {t('in_person_proofing.body.welcome.bring_barcode_header')}
            </IconListTitle>
            <p>{t('in_person_proofing.body.welcome.bring_barcode_info')}</p>
          </IconListContent>
        </IconListItem>

        <IconListItem>
          <IconListIcon className="text-indigo">
            <Icon icon="check_circle" />
          </IconListIcon>
          <IconListContent>
            <IconListTitle>{t('in_person_proofing.body.welcome.bring_id_header')}</IconListTitle>
            <p>{t('in_person_proofing.body.welcome.bring_id_info_acceptable')}</p>
            <ul>
              <li>{t('in_person_proofing.body.welcome.bring_id_info_dl')}</li>
              <li>{t('in_person_proofing.body.welcome.bring_id_info_id_card')}</li>
            </ul>
            <p>{t('in_person_proofing.body.welcome.bring_id_info_no_other_forms')}</p>
          </IconListContent>
        </IconListItem>

        <IconListItem>
          <IconListIcon className="text-indigo">
            <Icon icon="check_circle" />
          </IconListIcon>
          <IconListContent>
            <IconListTitle>{t('in_person_proofing.body.welcome.bring_proof_header')}</IconListTitle>
            <p>{t('in_person_proofing.body.welcome.bring_proof_info_acceptable')}</p>
            <ul>
              <li>{t('in_person_proofing.body.welcome.bring_proof_info_lease')}</li>
              <li>{t('in_person_proofing.body.welcome.bring_proof_info_registration')}</li>
              <li>{t('in_person_proofing.body.welcome.bring_proof_info_card')}</li>
              <li>{t('in_person_proofing.body.welcome.bring_proof_info_policy')}</li>
            </ul>
          </IconListContent>
        </IconListItem>
      </IconList>
      <FormStepsButton.Submit />
      <StartOverOrCancel />
    </>
  );
}

export default WelcomeStep;
