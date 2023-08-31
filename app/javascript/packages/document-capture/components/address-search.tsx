import { useState } from 'react';
import { Alert, PageHeading } from '@18f/identity-components';
import AddressSearchInput, { InPersonLocations } from '@18f/identity-address-search';
import type { LocationQuery, FormattedLocation } from '@18f/identity-address-search/types';
import { useI18n } from '@18f/identity-react-i18n';

function AddressSearch({
  registerField,
  locationsURL,
  addressSearchURL,
  handleLocationSelect,
  disabled,
  onFoundLocations,
  NoResultsHelpCenterMessage,
}) {
  const [apiError, setApiError] = useState<Error | null>(null);
  const [foundAddress, setFoundAddress] = useState<LocationQuery | null>(null);
  const [locationResults, setLocationResults] = useState<FormattedLocation[] | null | undefined>(
    null,
  );
  const [isLoadingLocations, setLoadingLocations] = useState<boolean>(false);
  const { t } = useI18n();

  return (
    <>
      {apiError && (
        <Alert type="error" className="margin-bottom-4">
          {t('idv.failure.exceptions.post_office_search_error')}
        </Alert>
      )}
      <PageHeading>{t('in_person_proofing.headings.po_search.location')}</PageHeading>
      <p>{t('in_person_proofing.body.location.po_search.po_search_about')}</p>
      <AddressSearchInput
        registerField={registerField}
        onFoundAddress={setFoundAddress}
        onFoundLocations={(locations) => {
          setLocationResults(locations);
          onFoundLocations(locations);
        }}
        onLoadingLocations={setLoadingLocations}
        onError={setApiError}
        disabled={disabled}
        locationsURL={locationsURL}
        addressSearchURL={addressSearchURL}
      />
      {locationResults && foundAddress && !isLoadingLocations && (
        <InPersonLocations
          locations={locationResults}
          onSelect={handleLocationSelect}
          address={foundAddress?.address || ''}
          NoResultsHelpCenterMessage={NoResultsHelpCenterMessage}
        />
      )}
    </>
  );
}

export default AddressSearch;
