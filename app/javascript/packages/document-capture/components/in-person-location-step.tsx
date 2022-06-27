import { PageHeading } from '@18f/identity-components';
import { FormStepsButton } from '@18f/identity-form-steps';
import { useI18n } from '@18f/identity-react-i18n';

function InPersonLocationStep() {
  const { t } = useI18n();

  return (
    <>
      <PageHeading>{t('in_person_proofing.headings.location')}</PageHeading>
      <FormStepsButton.Continue />
    </>
  );
}

export default InPersonLocationStep;
