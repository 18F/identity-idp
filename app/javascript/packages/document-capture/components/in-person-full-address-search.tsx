import { TextInput, SelectInput } from '@18f/identity-components';
import { useState, useRef, useEffect, useCallback, useContext } from 'react';
import { t } from '@18f/identity-i18n';
import ValidatedField from '@18f/identity-validated-field/validated-field';
import SpinnerButton, { SpinnerButtonRefHandle } from '@18f/identity-spinner-button/spinner-button';
import type { RegisterFieldCallback } from '@18f/identity-form-steps';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import type { LocationQuery, FormattedLocation } from '@18f/identity-address-search/types';
import { InPersonContext } from '../context';
import useValidatedUspsLocations from '../hooks/use-validated-usps-locations';

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
  } = useValidatedUspsLocations(locationsURL);

  const inputChangeHandler =
    <T extends HTMLElement & { value: string }>(input) =>
    (event: React.ChangeEvent<T>) => {
      const { target } = event;
      input(target.value);
    };

  type SelectChangeEvent = React.ChangeEvent<HTMLSelectElement>;

  const onAddressChange = inputChangeHandler(setAddressValue);
  const onCityChange = inputChangeHandler(setCityValue);
  const onStateChange = (e: SelectChangeEvent) => setStateValue(e.target.value);
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
      <ValidatedField
        ref={validatedAddressFieldRef}
        messages={{
          patternMismatch: t('simple_form.required.text'),
        }}
      >
        <TextInput
          required
          ref={registerField('address')}
          value={addressValue}
          onChange={onAddressChange}
          label={t('in_person_proofing.body.location.po_search.address_label')}
          disabled={disabled}
          maxLength={255}
          pattern=".*\S.*$"
        />
      </ValidatedField>
      <ValidatedField
        ref={validatedCityFieldRef}
        messages={{
          patternMismatch: t('simple_form.required.text'),
        }}
      >
        <TextInput
          required
          ref={registerField('city')}
          value={cityValue}
          onChange={onCityChange}
          label={t('in_person_proofing.body.location.po_search.city_label')}
          disabled={disabled}
          maxLength={50}
          pattern=".*\S.*$"
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
          patternMismatch: t('idv.errors.pattern_mismatch.zipcode_five'),
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
          pattern="^\d{5}$"
          maxLength={5}
          minLength={5}
          type="text"
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
