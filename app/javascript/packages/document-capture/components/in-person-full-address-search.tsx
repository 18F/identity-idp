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

  const checkValidityAndDisplayErrors = ((address, city, state, zipCode) => {
    let formIsValid = true;
    const validZipCodeLength = zipCode.length === 5 || zipCode.length === 10;
    
    if (address.length === 0) {
      validatedAddressFieldRef.current?.setCustomValidity(t('simple_form.required.text'));
      formIsValid = false
    } else {
      validatedAddressFieldRef.current?.setCustomValidity('');
    }

    if (city.length === 0) {
      formIsValid = false
      validatedCityFieldRef.current?.setCustomValidity(t('simple_form.required.text'));
    } else {
      validatedCityFieldRef.current?.setCustomValidity('');
    }

    if (state.length === 0) {
      formIsValid = false
      validatedStateFieldRef.current?.setCustomValidity(t('simple_form.required.text'));
    } else {
      validatedStateFieldRef.current?.setCustomValidity('');
    }

    if (zipCode.length === 0) {
      formIsValid = false
      validatedZipCodeFieldRef.current?.setCustomValidity(t('simple_form.required.text'));
    } else {
      validatedZipCodeFieldRef.current?.setCustomValidity('');
    }

    validatedAddressFieldRef.current?.reportValidity();
    validatedCityFieldRef.current?.reportValidity();
    validatedStateFieldRef.current?.reportValidity();
    validatedZipCodeFieldRef.current?.reportValidity();

    return formIsValid && validZipCodeLength
  })

  const handleLocationSearch = useCallback(
    (event, addressValue, cityValue, stateValue, zipCodeValue) => {
      event.preventDefault();
      const address = addressValue.trim();
      const city = cityValue.trim();

      const formIsValid = checkValidityAndDisplayErrors(address, city, stateValue, zipCodeValue)

      if (!formIsValid) {
        return;
      }

      setLocationQuery({
        address: `${address}, ${city}, ${stateValue} ${zipCodeValue}`,
        streetAddress: address,
        city: city,
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

  const inputChangeHandlerForZipCode =
    <T extends HTMLElement & { value: string }>(input) =>
    (event: React.ChangeEvent<T>) => {
      const { target } = event;
      const scrubbedZip = target.value.replace(/[^0-9]/g, '');
      if (scrubbedZip.length > 5) {
        const zipcodePieces: string[] = [];
        zipcodePieces.push(scrubbedZip.substring(0, 5));
        zipcodePieces.push(scrubbedZip.substring(5));
        input(zipcodePieces.join('-'));
      } else {
        input(scrubbedZip);
      }
    };

  type InputChangeEvent = React.ChangeEvent<HTMLInputElement>;
  type SelectChangeEvent = React.ChangeEvent<HTMLSelectElement>;

  const onAddressChange = (e: InputChangeEvent) =>
    setAddressValue(e.target.value.replace(/[^a-zA-Z0-9_ ]/gi, ''));
  const onCityChange = (e: InputChangeEvent) =>
    setCityValue(e.target.value.replace(/[^a-zA-Z0-9-'_ ]/gi, ''));
  const onStateChange = (e: SelectChangeEvent) => setStateValue(e.target.value.trimStart());
  const onZipCodeChange = inputChangeHandlerForZipCode(setZipCodeValue);

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
          maxLength={255}
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
          maxLength={50}
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
      <ValidatedField
        ref={validatedZipCodeFieldRef}
        messages={{
          patternMismatch: t('idv.errors.pattern_mismatch.zipcode'),
        }}
      >
        <TextInput
          required
          className="tablet:grid-col-5"
          ref={registerField('zip_code')}
          value={zipCodeValue}
          onChange={onZipCodeChange}
          label={t('in_person_proofing.body.location.po_search.zipcode_label')}
          disabled={disabled}
          pattern="(\d{5}([\-]\d{4})?)"
          maxLength={10}
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
