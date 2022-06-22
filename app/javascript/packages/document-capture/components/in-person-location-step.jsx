import { PageHeading } from '@18f/identity-components';
import { FormStepsButton } from '@18f/identity-form-steps';
import { useI18n } from '@18f/identity-react-i18n';

/**
 * @typedef InPersonLocationStepValue
 *
 * @prop {Blob|string|null|undefined} inPersonLocation InPersonLocation value.
 */

/**
 * @param {import('@18f/identity-form-steps').FormStepComponentProps<InPersonLocationValue>} props Props object.
 */
function InPersonLocationStep({ errors = [] }) {
  const { t } = useI18n();
  const error = errors.find(({ field }) => field === 'in-person-location')?.error;

  return (
    <>
      <PageHeading>{t('in_person_proofing.headings.location')}</PageHeading>
      <FormStepsButton.Continue />
    </>
  );
}

export default InPersonLocationStep;
