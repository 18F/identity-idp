import { TextInput, SelectInput } from '@18f/identity-components';
import { useState, useRef, useEffect, useCallback, useContext } from 'react';
import { t } from '@18f/identity-i18n';
import { request } from '@18f/identity-request';
import ValidatedField from '@18f/identity-validated-field/validated-field';
import SpinnerButton, { SpinnerButtonRefHandle } from '@18f/identity-spinner-button/spinner-button';
import type { RegisterFieldCallback } from '@18f/identity-form-steps';
import useSWR from 'swr/immutable';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import { transformKeys, snakeCase } from '@18f/identity-address-search';
import type {
  LocationQuery,
  PostOffice,
  FormattedLocation,
} from '@18f/identity-address-search/types';
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

const requestUspsLocations = async ({
  address,
  locationsURL,
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

function useUspsLocations(locationsURL: string) {
  const [locationQuery, setLocationQuery] = useState<LocationQuery | null>(null);
  const validatedAddressFieldRef = useRef<HTMLFormElement>(null);
  const validatedCityFieldRef = useRef<HTMLFormElement>(null);
  const validatedStateFieldRef = useRef<HTMLFormElement>(null);
  const validatedZipCodeFieldRef = useRef<HTMLFormElement>(null);

  const handleLocationSearch = useCallback(
    (event, addressValue, cityValue, stateValue, zipCodeValue) => {
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
        addressValue.trim().length === 0 ||
        cityValue.trim().length === 0 ||
        stateValue.trim().length === 0 ||
        zipCodeValue.trim().length === 0
      ) {
        return;
      }

      setLocationQuery({
        address: `${addressValue}, ${cityValue}, ${stateValue} ${zipCodeValue}`,
        streetAddress: addressValue,
        city: cityValue,
        state: stateValue,
        zipCode: zipCodeValue,
      });
    },
    [],
  );

  const {
    data: locationResults,
    isLoading: isLoadingLocations,
    error: uspsError,
  } = useSWR([locationQuery], ([address]) =>
    address ? requestUspsLocations({ address, locationsURL }) : null,
  );

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
    address: LocationQuery | null,
    locations: FormattedLocation[] | null | undefined,
  ) => void;
  onLoadingLocations?: (isLoading: boolean) => void;
  onError?: (error: Error | null) => void;
  disabled?: boolean;
  locationsURL: string;
}

function FullAddressSearch({
  registerField = () => undefined,
  onFoundLocations = () => undefined,
  onLoadingLocations = () => undefined,
  onError = () => undefined,
  disabled = false,
  locationsURL,
}: FullAddressSearchProps) {
  const spinnerButtonRef = useRef<SpinnerButtonRefHandle>(null);
  const [addressValue, setAddressValue] = useState('');
  const [cityValue, setCityValue] = useState('');
  const [stateValue, setStateValue] = useState('');
  const [zipCodeValue, setZipCodeValue] = useState('');
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
  } = useUspsLocations(locationsURL);

  const inputChangeHandler =
    <T extends HTMLElement & { value: string }>(input) =>
    (event: React.ChangeEvent<T>) => {
      const { target } = event;
      input(target.value);
    };

  const onAddressChange = inputChangeHandler(setAddressValue);
  const onCityChange = inputChangeHandler(setCityValue);
  const onStateChange = inputChangeHandler(setStateValue);
  const onZipCodeChange = inputChangeHandler(setZipCodeValue);

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
      onSearch(event, addressValue, cityValue, stateValue, zipCodeValue);
    },
    [addressValue, cityValue, stateValue, zipCodeValue],
  );

  const { usStatesTerritories } = useContext(InPersonContext);

  return (
    <>
      <ValidatedField ref={validatedAddressFieldRef}>
        <TextInput
          required
          ref={registerField('address')}
          value={addressValue}
          onChange={onAddressChange}
          label={t('in_person_proofing.body.location.po_search.address_label')}
          disabled={disabled}
        />
      </ValidatedField>
      <ValidatedField ref={validatedCityFieldRef}>
        <TextInput
          required
          ref={registerField('city')}
          value={cityValue}
          onChange={onCityChange}
          label={t('in_person_proofing.body.location.po_search.city_label')}
          disabled={disabled}
        />
      </ValidatedField>
      <ValidatedField ref={validatedStateFieldRef}>
        <SelectInput
          required
          ref={registerField('state')}
          value={stateValue}
          onChange={onStateChange}
          label={t('in_person_proofing.body.location.po_search.state_label')}
          disabled={disabled}
        >
          <option key="select" value="" disabled>
            {t('in_person_proofing.form.address.state_prompt')}
          </option>
          {usStatesTerritories.map(([name, abbr]) => (
            <option key={abbr} value={abbr}>
              {name}
            </option>
          ))}
        </SelectInput>
      </ValidatedField>
      <ValidatedField ref={validatedZipCodeFieldRef}>
        <TextInput
          required
          className="tablet:grid-col-5"
          ref={registerField('zip_code')}
          value={zipCodeValue}
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
