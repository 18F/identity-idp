import { useState, useRef, useEffect, useCallback } from 'react';
import { request } from '@18f/identity-request';
import { t } from '@18f/identity-i18n';
import useSWR from 'swr/immutable';
import type { Location, FormattedLocation, LocationQuery, PostOffice } from '../types';
import { formatLocations, snakeCase, transformKeys } from '../utils';

const requestUspsLocations = async ({
  locationsURL,
  address,
}: {
  locationsURL: string;
  address: LocationQuery;
}): Promise<FormattedLocation[]> => {
  const response = await request<PostOffice[]>(locationsURL, {
    method: 'post',
    json: { address: transformKeys(address, snakeCase) },
  });

  return formatLocations(response);
};

function requestAddressCandidates({
  unvalidatedAddressInput,
  addressSearchURL,
}: {
  unvalidatedAddressInput: string;
  addressSearchURL: string;
}): Promise<Location[]> {
  return request<Location[]>(addressSearchURL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    json: { address: unvalidatedAddressInput },
  });
}

export default function useUspsLocations({
  locationsURL,
  addressSearchURL,
}: {
  locationsURL: string;
  addressSearchURL: string;
}) {
  // raw text input that is set when user clicks search
  const [addressQuery, setAddressQuery] = useState('');
  const validatedFieldRef = useRef<HTMLFormElement>(null);
  const handleAddressSearch = useCallback((event, unvalidatedAddressInput) => {
    event.preventDefault();
    validatedFieldRef.current?.setCustomValidity('');
    validatedFieldRef.current?.reportValidity();

    if (unvalidatedAddressInput === '') {
      return;
    }

    setAddressQuery(unvalidatedAddressInput);
  }, []);

  // sends the raw text query to arcgis
  const {
    data: addressCandidates,
    isLoading: isLoadingCandidates,
    error: addressError,
  } = useSWR([addressQuery], () =>
    addressQuery
      ? requestAddressCandidates({ unvalidatedAddressInput: addressQuery, addressSearchURL })
      : null,
  );

  const [foundAddress, setFoundAddress] = useState<LocationQuery | null>(null);

  useEffect(() => {
    if (addressCandidates?.[0]) {
      const bestMatchedAddress = addressCandidates[0];
      setFoundAddress({
        streetAddress: bestMatchedAddress.street_address,
        city: bestMatchedAddress.city,
        state: bestMatchedAddress.state,
        zipCode: bestMatchedAddress.zip_code,
        address: bestMatchedAddress.address,
      });
    } else if (addressCandidates) {
      validatedFieldRef?.current?.setCustomValidity(
        t('in_person_proofing.body.location.inline_error'),
      );
      validatedFieldRef?.current?.reportValidity();
      setFoundAddress(null);
    }
  }, [addressCandidates]);

  const {
    data: locationResults,
    isLoading: isLoadingLocations,
    error: uspsError,
  } = useSWR([foundAddress], ([address]) =>
    address ? requestUspsLocations({ locationsURL, address }) : null,
  );

  return {
    foundAddress,
    locationResults,
    uspsError,
    addressError,
    isLoading: isLoadingLocations || isLoadingCandidates,
    handleAddressSearch,
    validatedFieldRef,
  };
}
