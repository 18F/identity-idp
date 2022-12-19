import { useState, useEffect, useCallback, useRef, useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { PageHeading } from '@18f/identity-components';
import { request } from '@18f/identity-request';
import useSWR from 'swr';
import BackButton from './back-button';
import AnalyticsContext from '../context/analytics';
import AddressSearch from './address-search';
import InPersonLocations, { FormattedLocation } from './in-person-locations';

interface PostOffice {
  address: string;
  city: string;
  name: string;
  phone: string;
  saturday_hours: string;
  state: string;
  sunday_hours: string;
  weekday_hours: string;
  zip_code_4: string;
  zip_code_5: string;
}

interface LocationQuery {
  streetAddress: string;
  city: string;
  state: string;
  zipCode: string;
  address: string;
}

export const LOCATIONS_URL = '/verify/in_person/usps_locations';

const formatLocation = (postOffices: PostOffice[]) => {
  const formattedLocations = [] as FormattedLocation[];
  postOffices.forEach((po: PostOffice, index) => {
    const location = {
      formattedCityStateZip: `${po.city}, ${po.state}, ${po.zip_code_5}-${po.zip_code_4}`,
      id: index,
      name: po.name,
      phone: po.phone,
      saturdayHours: po.saturday_hours,
      streetAddress: po.address,
      sundayHours: po.sunday_hours,
      weekdayHours: po.weekday_hours,
    } as FormattedLocation;
    formattedLocations.push(location);
  });
  return formattedLocations;
};

const snakeCase = (value: string) =>
  value
    .split(/(?=[A-Z])/)
    .join('_')
    .toLowerCase();

// snake case the keys of the location
const transformKeys = (location: object, predicate: (key: string) => string) =>
  Object.keys(location).reduce(
    (acc, key) => ({
      [predicate(key)]: location[key],
      ...acc,
    }),
    {},
  );

const requestUspsLocations = async (address: LocationQuery): Promise<FormattedLocation[]> => {
  const response = await request<PostOffice[]>(LOCATIONS_URL, {
    method: 'post',
    json: { address: transformKeys(address, snakeCase) },
  });

  return formatLocation(response);
};

const ADDRESS_SEARCH_URL = '/api/addresses';

function requestAddressCandidates(unvalidatedAddressInput: string): Promise<Location[]> {
  return request<Location[]>(ADDRESS_SEARCH_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    json: { address: unvalidatedAddressInput },
  });
}

function useUspsLocations() {
  const [foundAddress, setFoundAddress] = useState<LocationQuery | null>(null);
  const { data: locationResults, isLoading: isLoadingLocations } = useSWR(
    [LOCATIONS_URL, foundAddress],
    ([, address]) => (address ? requestUspsLocations(address) : null),
  );
  const handleFoundAddress = useCallback((address) => {
    setFoundAddress({
      streetAddress: address.street_address,
      city: address.city,
      state: address.state,
      zipCode: address.zip_code,
      address: address.address,
    });
  }, []);

  const [unvalidatedAddressInput, setUnvalidatedAddressInput] = useState('');
  function onAddressChanged(event) {
    const target = event.target as HTMLInputElement;
    setUnvalidatedAddressInput(target.value);
  }

  const validatedFieldRef = useRef<HTMLFormElement | null>(null);
  const [addressQuery, setAddressQuery] = useState('');
  const { data: addressCandidates, isLoading: isLoadingCandidates } = useSWR(
    [ADDRESS_SEARCH_URL, addressQuery],
    () => (addressQuery ? requestAddressCandidates(unvalidatedAddressInput) : null),
  );
  const handleAddressSearch = useCallback(
    (event) => {
      event.preventDefault();
      validatedFieldRef.current?.reportValidity();
      if (unvalidatedAddressInput === '') {
        return;
      }

      setAddressQuery(unvalidatedAddressInput);
    },
    [unvalidatedAddressInput],
  );

  useEffect(() => {
    if (addressCandidates) {
      const bestMatchedAddress = addressCandidates[0];
      handleFoundAddress(bestMatchedAddress);
    }
  }, [addressCandidates]);

  return [
    foundAddress,
    locationResults,
    unvalidatedAddressInput,
    validatedFieldRef,
    isLoadingLocations || isLoadingCandidates,
    onAddressChanged,
    handleAddressSearch,
  ];
}

function InPersonLocationPostOfficeSearchStep({ onChange, toPreviousStep, registerField }) {
  const { t } = useI18n();
  const [inProgress, setInProgress] = useState(false);
  const [autoSubmit, setAutoSubmit] = useState(false);
  const { setSubmitEventMetadata } = useContext(AnalyticsContext);
  const [
    foundAddress,
    locationResults,
    unvalidatedAddressInput,
    validatedFieldRef,
    isLoading,
    onAddressChanged,
    handleAddressSearch,
  ] = useUspsLocations();

  // ref allows us to avoid a memory leak
  const mountedRef = useRef(false);

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
    };
  }, []);

  // useCallBack here prevents unnecessary rerenders due to changing function identity
  const handleLocationSelect = useCallback(
    async (e: any, id: number) => {
      const selectedLocation = locationResults![id]!;
      const { name: selectedLocationName } = selectedLocation;
      setSubmitEventMetadata({ selected_location: selectedLocationName });
      onChange({ selectedLocationName });
      if (autoSubmit) {
        return;
      }
      // prevent navigation from continuing
      e.preventDefault();
      if (inProgress) {
        return;
      }
      const selected = transformKeys(selectedLocation, snakeCase);
      setInProgress(true);
      await request(LOCATIONS_URL, {
        json: selected,
        method: 'PUT',
      })
        .then(() => {
          if (!mountedRef.current) {
            return;
          }
          setAutoSubmit(true);
          setImmediate(() => {
            // continue with navigation
            e.target.click();
            // allow process to be re-triggered in case submission did not work as expected
            setAutoSubmit(false);
          });
        })
        .finally(() => {
          if (!mountedRef.current) {
            return;
          }
          setInProgress(false);
        });
    },
    [locationResults, inProgress],
  );

  return (
    <>
      <PageHeading>{t('in_person_proofing.headings.po_search.location')}</PageHeading>
      <p>{t('in_person_proofing.body.location.po_search.po_search_about')}</p>
      <AddressSearch
        registerField={registerField}
        unvalidatedAddressInput={unvalidatedAddressInput}
        onAddressChanged={onAddressChanged}
        validatedFieldRef={validatedFieldRef}
        onSearch={handleAddressSearch}
        loading={isLoading}
      />
      {locationResults && (
        <InPersonLocations
          locations={locationResults}
          onSelect={handleLocationSelect}
          address={foundAddress?.address || ''}
        />
      )}
      <BackButton includeBorder onClick={toPreviousStep} />
    </>
  );
}

export default InPersonLocationPostOfficeSearchStep;
