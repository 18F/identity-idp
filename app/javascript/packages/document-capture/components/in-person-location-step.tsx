import { PageHeading, LocationCollectionItem, LocationCollection } from '@18f/identity-components';
import { FormStepsButton } from '@18f/identity-form-steps';
import { useI18n } from '@18f/identity-react-i18n';

function InPersonLocationStep() {
  const { t } = useI18n();

  return (
    <>
      <PageHeading>{t('in_person_proofing.headings.location')}</PageHeading>

      <p>{t('in_person_proofing.body.location.location_step_about')}</p>
      <LocationCollection>
        <LocationCollectionItem header="BALTIMORE — Post Office &#8482;"> </LocationCollectionItem>
        <LocationCollectionItem header="COURAGE — Post Office &#8482;"> </LocationCollectionItem>
      </LocationCollection>
      <FormStepsButton.Continue />
    </>
  );
}

export default InPersonLocationStep;
