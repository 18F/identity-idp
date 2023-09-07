import { Dispatch, SetStateAction, useState } from 'react';
import { Alert, PageHeading } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import type { RegisterFieldCallback } from '@18f/identity-form-steps';
import InPersonLocations from './in-person-locations';
import AddressInput from './address-input';
import type { LocationQuery, FormattedLocation } from '../types';

interface AddressSearchProps {
  addressSearchURL: string;
  disabled: boolean;
  handleLocationSelect: ((e: any, id: number) => Promise<void>) | null | undefined;
  infoAlertURL?: string;
  locationsURL: string;
  onFoundLocations: Dispatch<SetStateAction<FormattedLocation[] | null | undefined>>;
  registerField: RegisterFieldCallback;
}

function AddressSearch({
  addressSearchURL,
  disabled,
  handleLocationSelect,
  infoAlertURL,
  locationsURL,
  onFoundLocations,
  registerField,
}: AddressSearchProps) {
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
      <AddressInput
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
          infoAlertURL={infoAlertURL}
        />
      )}
    </>
  );
}

export default AddressSearch;
