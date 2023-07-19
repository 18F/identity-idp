import { useI18n } from '@18f/identity-react-i18n';
import { PageHeading } from '@18f/identity-components';
import BackButton from './back-button';

function InPersonLocationFullAddressEntryPostOfficeSearchStep({ toPreviousStep }) {
  const { t } = useI18n();

  return (
    <>
      <PageHeading>{t('in_person_proofing.headings.po_search.location')}</PageHeading>
      <p>{t('in_person_proofing.body.location.po_search.po_search_about')}</p>
      <BackButton role="link" includeBorder onClick={toPreviousStep} />
    </>
  );
}

export default InPersonLocationFullAddressEntryPostOfficeSearchStep;
