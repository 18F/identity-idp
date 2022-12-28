import { TextInput } from '@18f/identity-components';
import { useState, useRef, useEffect, useCallback } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { request } from '@18f/identity-request';
import ValidatedField from '@18f/identity-validated-field/validated-field';
import SpinnerButton, { SpinnerButtonRefHandle } from '@18f/identity-spinner-button/spinner-button';
import type { RegisterFieldCallback } from '@18f/identity-form-steps';
import useSWR from 'swr/immutable';
import { FormattedLocation } from './in-person-locations';

export const LOCATIONS_URL = '/verify/in_person/usps_locations';

export interface PostOffice {
  address: string;
  city: string;
  distance: string;
  name: string;
  phone: string;
  saturday_hours: string;
  state: string;
  sunday_hours: string;
  tty: string;
  weekday_hours: string;
  zip_code_4: string;
  zip_code_5: string;
}

export interface LocationQuery {
  streetAddress: string;
  city: string;
  state: string;
  zipCode: string;
  address: string;
}

interface Location {
  street_address: string;
  city: string;
  state: string;
  zip_code: string;
  address: string;
}

const formatLocation = (postOffices: PostOffice[]) => {
  const formattedLocations = [] as FormattedLocation[];
  postOffices.forEach((po: PostOffice, index) => {
    const location = {
      formattedCityStateZip: `${po.city}, ${po.state}, ${po.zip_code_5}-${po.zip_code_4}`,
      id: index,
      distance: po.distance,
      name: po.name,
      phone: po.phone,
      saturdayHours: po.saturday_hours,
      streetAddress: po.address,
      sundayHours: po.sunday_hours,
      tty: po.tty,
      weekdayHours: po.weekday_hours,
    } as FormattedLocation;
    formattedLocations.push(location);
  });
  return formattedLocations;
};

export const snakeCase = (value: string) =>
  value
    .split(/(?=[A-Z])/)
    .join('_')
    .toLowerCase();

// snake case the keys of the location
export const transformKeys = (location: object, predicate: (key: string) => string) =>
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

export const ADDRESS_SEARCH_URL = '/api/addresses';

function requestAddressCandidates(unvalidatedAddressInput: string): Promise<Location[]> {
  return request<Location[]>(ADDRESS_SEARCH_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    json: { address: unvalidatedAddressInput },
  });
}

function useUspsLocations() {
  // raw text input that is set when user clicks search
  const [addressQuery, setAddressQuery] = useState('');
  const validatedFieldRef = useRef<HTMLFormElement>(null);
  const { t } = useI18n();
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
  const { data: addressCandidates, isLoading: isLoadingCandidates } = useSWR(
    [addressQuery],
    () => (addressQuery ? requestAddressCandidates(addressQuery) : null),
    { keepPreviousData: true },
  );

  // sets the arcgis-validated address object
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
    }
  }, [addressCandidates]);

  const { data: locationResults, isLoading: isLoadingLocations } = useSWR(
    [foundAddress],
    ([address]) => (address ? requestUspsLocations(address) : null),
    { keepPreviousData: true },
  );

  return {
    foundAddress,
    locationResults,
    isLoading: isLoadingLocations || isLoadingCandidates,
    handleAddressSearch,
    validatedFieldRef,
  };
}

interface AddressSearchProps {
  registerField?: RegisterFieldCallback;
  onFoundAddress?: (address: LocationQuery) => void;
  onFoundLocations?: (locations: FormattedLocation[]) => void;
}

function AddressSearch({
  registerField = () => undefined,
  onFoundAddress = () => undefined,
  onFoundLocations = () => undefined,
}: AddressSearchProps) {
  const { t } = useI18n();
  const spinnerButtonRef = useRef<SpinnerButtonRefHandle>(null);
  const [textInput, setTextInput] = useState('');
  const {
    locationResults,
    isLoading,
    handleAddressSearch: onSearch,
    foundAddress,
    validatedFieldRef,
  } = useUspsLocations();

  const onTextInputChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const { target } = event;
    setTextInput(target.value);
  };

  useEffect(() => {
    spinnerButtonRef.current?.toggleSpinner(isLoading);
  }, [isLoading]);

  useEffect(() => {
    locationResults && onFoundLocations(locationResults);
    foundAddress && onFoundAddress(foundAddress);
  }, [locationResults, foundAddress]);

  const handleSearch = useCallback(
    (event) => {
      onSearch(event, textInput);
    },
    [textInput],
  );

  return (
    <>
      <ValidatedField
        ref={validatedFieldRef}
        messages={{
          valueMissing: t('in_person_proofing.body.location.inline_error'),
        }}
      >
        <TextInput
          required
          ref={registerField('address')}
          value={textInput}
          onChange={onTextInputChange}
          label={t('in_person_proofing.body.location.po_search.address_search_label')}
          hint={t('in_person_proofing.body.location.po_search.address_search_hint')}
        />
      </ValidatedField>
      <div className="margin-y-5">
        <SpinnerButton
          isWide
          isBig
          ref={spinnerButtonRef}
          type="submit"
          onClick={handleSearch}
          spinOnClick={false}
          actionMessage={t('in_person_proofing.body.location.po_search.is_searching_message')}
          longWaitDurationMs={1}
        >
          {t('in_person_proofing.body.location.po_search.search_button')}
        </SpinnerButton>
      </div>
    </>
  );
}

export default AddressSearch;
