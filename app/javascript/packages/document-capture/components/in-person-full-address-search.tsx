import { TextInput, SelectInput } from '@18f/identity-components';
import { useState, useRef, useEffect, useCallback, useContext } from 'react';
import { t } from '@18f/identity-i18n';
import { request } from '@18f/identity-request';
import ValidatedField from '@18f/identity-validated-field/validated-field';
import SpinnerButton, { SpinnerButtonRefHandle } from '@18f/identity-spinner-button/spinner-button';
import type { RegisterFieldCallback } from '@18f/identity-form-steps';
import useSWR from 'swr/immutable';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import {
  FormattedLocation,
  transformKeys,
  snakeCase,
  LocationQuery,
  LOCATIONS_URL,
  PostOffice,
} from '@18f/identity-address-search';
import { InPersonContext } from '../context';

const formatLocations = (postOffices: PostOffice[]): FormattedLocation[] =>
  postOffices.map((po: PostOffice, index) => ({
    formattedCityStateZip: `${po.city}, ${po.state}, ${po.zip_code_5}-${po.zip_code_4}`,
    id: index,
    distance: po.distance,
    name: po.name,
    saturdayHours: po.saturday_hours,
    streetAddress: po.address,
    sundayHours: po.sunday_hours,
    weekdayHours: po.weekday_hours,
    isPilot: !!po.is_pilot,
  }));

const requestUspsLocations = async (address: LocationQuery): Promise<FormattedLocation[]> => {
  const response = await request<PostOffice[]>(LOCATIONS_URL, {
    method: 'post',
    json: { address: transformKeys(address, snakeCase) },
  });

  return formatLocations(response);
};

function useUspsLocations() {
  const [locationQuery, setLocationQuery] = useState<LocationQuery | null>(null);
  const validatedAddressFieldRef = useRef<HTMLFormElement>(null);
  const validatedCityFieldRef = useRef<HTMLFormElement>(null);
  const validatedStateFieldRef = useRef<HTMLFormElement>(null);
  const validatedZipCodeFieldRef = useRef<HTMLFormElement>(null);

  const handleLocationSearch = useCallback(
    (event, addressInput, cityInput, stateInput, zipCodeInput) => {
      event.preventDefault();
      validatedAddressFieldRef.current?.setCustomValidity('');
      validatedAddressFieldRef.current?.reportValidity();
      validatedCityFieldRef.current?.setCustomValidity('');
      validatedCityFieldRef.current?.reportValidity();
      validatedStateFieldRef.current?.setCustomValidity('');
      validatedStateFieldRef.current?.reportValidity();
      validatedZipCodeFieldRef.current?.setCustomValidity('');
      validatedZipCodeFieldRef.current?.reportValidity();

      if (
        addressInput.trim().length === 0 ||
        cityInput.trim().length === 0 ||
        stateInput.trim().length === 0 ||
        zipCodeInput.trim().length === 0
      ) {
        return;
      }

      setLocationQuery({
        address: `${addressInput}, ${cityInput}, ${stateInput} ${zipCodeInput}`,
        streetAddress: addressInput,
        city: cityInput,
        state: stateInput,
        zipCode: zipCodeInput,
      });
    },
    [],
  );

  const {
    data: locationResults,
    isLoading: isLoadingLocations,
    error: uspsError,
  } = useSWR([locationQuery], ([address]) => (address ? requestUspsLocations(address) : null));

  return {
    locationQuery,
    locationResults,
    uspsError,
    isLoading: isLoadingLocations,
    handleLocationSearch,
    validatedAddressFieldRef,
    validatedCityFieldRef,
    validatedStateFieldRef,
    validatedZipCodeFieldRef,
  };
}

interface FullAddressSearchProps {
  registerField?: RegisterFieldCallback;
  onFoundLocations?: (
    address: LocationQuery,
    locations: FormattedLocation[] | null | undefined,
  ) => void;
  onLoadingLocations?: (isLoading: boolean) => void;
  onError?: (error: Error | null) => void;
  disabled?: boolean;
}

function FullAddressSearch({
  registerField = () => undefined,
  onFoundLocations = () => undefined,
  onLoadingLocations = () => undefined,
  onError = () => undefined,
  disabled = false,
}: FullAddressSearchProps) {
  // todo: should we get rid of verbose 'input' word?
  const spinnerButtonRef = useRef<SpinnerButtonRefHandle>(null);
  const [addressInput, setAddressInput] = useState('');
  const [cityInput, setCityInput] = useState('');
  const [stateInput, setStateInput] = useState('');
  const [zipCodeInput, setZipCodeInput] = useState('');
  const {
    locationQuery,
    locationResults,
    uspsError,
    isLoading,
    handleLocationSearch: onSearch,
    validatedAddressFieldRef,
    validatedCityFieldRef,
    validatedStateFieldRef,
    validatedZipCodeFieldRef,
  } = useUspsLocations();

  const inputChangeHandler =
    <T extends HTMLElement & { value: string }>(input) =>
    (event: React.ChangeEvent<T>) => {
      const { target } = event;
      input(target.value);
    };

  const onAddressChange = inputChangeHandler(setAddressInput);
  const onCityChange = inputChangeHandler(setCityInput);
  const onStateChange = inputChangeHandler(setStateInput);
  const onZipCodeChange = inputChangeHandler(setZipCodeInput);

  useEffect(() => {
    spinnerButtonRef.current?.toggleSpinner(isLoading);
    onLoadingLocations(isLoading);
  }, [isLoading]);

  useEffect(() => {
    uspsError && onError(uspsError);
  }, [uspsError]);

  useDidUpdateEffect(() => {
    onFoundLocations(locationQuery, locationResults);
  }, [locationResults]);

  const handleSearch = useCallback(
    (event) => {
      onError(null);
      onSearch(event, addressInput, cityInput, stateInput, zipCodeInput);
    },
    [addressInput, cityInput, stateInput, zipCodeInput],
  );

  const { usStatesTerritories } = useContext(InPersonContext);

  return (
    <>
      <ValidatedField ref={validatedAddressFieldRef}>
        <TextInput
          required
          ref={registerField('address')}
          value={addressInput}
          onChange={onAddressChange}
          label={t('in_person_proofing.body.location.po_search.address_label')}
          disabled={disabled}
        />
      </ValidatedField>
      <ValidatedField ref={validatedCityFieldRef}>
        <TextInput
          required
          ref={registerField('city')}
          value={cityInput}
          onChange={onCityChange}
          label={t('in_person_proofing.body.location.po_search.city_label')}
          disabled={disabled}
        />
      </ValidatedField>
      <ValidatedField ref={validatedStateFieldRef}>
        <SelectInput
          required
          ref={registerField('state')}
          value={stateInput}
          onChange={onStateChange}
          label={t('in_person_proofing.body.location.po_search.state_label')}
          disabled={disabled}
        >
          <option value="" disabled selected>
            {t('in_person_proofing.form.address.state_prompt')}
          </option>
          {usStatesTerritories.map(([name, abbr]) => (
            <option value={abbr}>{name}</option>
          ))}
        </SelectInput>
      </ValidatedField>
      <ValidatedField ref={validatedZipCodeFieldRef}>
        <TextInput
          required
          className="tablet:grid-col-5"
          ref={registerField('zip_code')}
          value={zipCodeInput}
          onChange={onZipCodeChange}
          label={t('in_person_proofing.body.location.po_search.zipcode_label')}
          disabled={disabled}
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

export default FullAddressSearch;
