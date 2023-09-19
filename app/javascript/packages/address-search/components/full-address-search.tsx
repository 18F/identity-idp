import { Alert, PageHeading } from '@18f/identity-components';
import { useState } from 'react';
import { t } from '@18f/identity-i18n';
import { InPersonLocations } from '@18f/identity-address-search';
import type { LocationQuery, FormattedLocation } from '@18f/identity-address-search/types';
import FullAddressSearchInput from './full-address-search-input';

function FullAddressSearch({
  usStatesTerritories,
  registerField,
  locationsURL,
  handleLocationSelect,
  disabled,
  onFoundLocations,
}) {
  const [apiError, setApiError] = useState<Error | null>(null);
  const [foundAddress, setFoundAddress] = useState<LocationQuery | null>(null);
  const [locationResults, setLocationResults] = useState<FormattedLocation[] | null | undefined>(
    null,
  );
  const [isLoadingLocations, setLoadingLocations] = useState<boolean>(false);

  return (
    <>
      {apiError && (
        <Alert type="error" className="margin-bottom-4">
          {t('idv.failure.exceptions.post_office_search_error')}
        </Alert>
      )}
      <PageHeading>{t('in_person_proofing.headings.po_search.location')}</PageHeading>
      <p>{t('in_person_proofing.body.location.po_search.po_search_about')}</p>
      <FullAddressSearchInput
        usStatesTerritories={usStatesTerritories}
        registerField={registerField}
        onFoundLocations={(
          address: LocationQuery | null,
          locations: FormattedLocation[] | null | undefined,
        ) => {
          setFoundAddress(address);
          setLocationResults(locations);
          onFoundLocations(locations);
        }}
        onLoadingLocations={setLoadingLocations}
        onError={setApiError}
        disabled={disabled}
        locationsURL={locationsURL}
      />
      {locationResults && foundAddress && !isLoadingLocations && (
        <InPersonLocations
          locations={locationResults}
          onSelect={handleLocationSelect}
          address={foundAddress.address || ''}
        />
      )}
    </>
  );
}

export default FullAddressSearch;
