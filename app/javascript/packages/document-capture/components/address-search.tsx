import { TextInput } from '@18f/identity-components';
import { useState, useRef, useEffect, RefObject, useCallback } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { request } from '@18f/identity-request';
import ValidatedField from '@18f/identity-validated-field/validated-field';
import SpinnerButton, { SpinnerButtonRefHandle } from '@18f/identity-spinner-button/spinner-button';
import type { RegisterFieldCallback } from '@18f/identity-form-steps';
import useSWR from 'swr/immutable';

interface AddressSearchProps {
  onSearch?: (
    event: MouseEvent,
    textInput: string,
    fieldValidationRef: RefObject<HTMLFormElement> | undefined,
  ) => void;
  registerField?: RegisterFieldCallback;
  loading?: boolean;
}

export const LOCATIONS_URL = '/verify/in_person/usps_locations';

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
  // raw text input that is set when user clicks search
  const [addressQuery, setAddressQuery] = useState('');
  const [fieldValidation, setFieldValidation] = useState<RefObject<HTMLFormElement>>();
  const validatedFieldRef = useRef<HTMLFormElement>(null);
  const { t } = useI18n();
  const handleAddressSearch = useCallback((event, unvalidatedAddressInput) => {
    event.preventDefault();
    validatedFieldRef.current?.setCustomValidity('');
    validatedFieldRef.current?.reportValidity();
    setFieldValidation(validatedFieldRef);
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
      fieldValidation?.current?.setCustomValidity(
        t('in_person_proofing.body.location.inline_error'),
      );
      fieldValidation?.current?.reportValidity();
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

function AddressSearch({
  registerField = () => undefined,
  // onSearch = () => {},
  // loading = false,
  onFoundAddress = () => undefined,
  onFoundLocations = () => undefined,
}: AddressSearchProps) {
  const { t } = useI18n();
  const spinnerButtonRef = useRef<SpinnerButtonRefHandle>(null);
  const [textInput, setTextInput] = useState('');
  const {
    locationResults,
    isLoading: loading,
    handleAddressSearch: onSearch,
    foundAddress,
    validatedFieldRef,
  } = useUspsLocations();

  const onTextInputChange = useCallback((event: React.ChangeEvent<HTMLInputElement>) => {
    const { target } = event;
    setTextInput(target.value);
  }, []);

  useEffect(() => {
    spinnerButtonRef.current?.toggleSpinner(loading);
  }, [loading]);

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
      <SpinnerButton
        isWide
        isBig
        ref={spinnerButtonRef}
        type="submit"
        className="margin-y-5"
        onClick={handleSearch}
        spinOnClick={false}
      >
        {t('in_person_proofing.body.location.po_search.search_button')}
      </SpinnerButton>
    </>
  );
}

export default AddressSearch;
