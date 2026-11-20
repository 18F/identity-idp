import { Button, TextInput, SelectInput } from '@18f/identity-components';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import { SpinnerButtonRefHandle, SpinnerButton } from '@18f/identity-spinner-button';
import { ValidatedField } from '@18f/identity-validated-field';
import { useI18n } from '@18f/identity-react-i18n';
import { useCallback, useEffect, useRef, useState } from 'react';
import useValidatedUspsLocations from '../hooks/use-validated-usps-locations';
import NDSTextInput from './nds-text-input';
import type { FullAddressSearchInputProps } from '../types';

export default function FullAddressSearchInput({
  disabled = false,
  locationsURL,
  onContinue,
  onError = () => undefined,
  onFoundLocations = () => undefined,
  onLoadingLocations = () => undefined,
  registerField = () => undefined,
  usStatesTerritories,
  uspsApiError,
  usesErrorComponent,
  nds = false,
}: FullAddressSearchInputProps) {
  const { t } = useI18n();
  const spinnerButtonRef = useRef<SpinnerButtonRefHandle>(null);
  const [addressValue, setAddressValue] = useState('');
  const [cityValue, setCityValue] = useState('');
  const [stateValue, setStateValue] = useState('');
  const [zipCodeValue, setZipCodeValue] = useState('');
  const [canSearch, setCanSearch] = useState(false);
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

  const handleContinue = useCallback(
    (event) => {
      // Run LocationSelect with null as the location
      onContinue!(event, null);
    },
    [uspsApiError],
  );

  const getErroneousAddressChars = () => {
    const addressReStr = validatedAddressFieldRef.current?.pattern;

    if (!addressReStr) {
      return;
    }

    const addressRegex = new RegExp(addressReStr, 'g');
    const errChars = addressValue.replace(addressRegex, '');
    const uniqErrChars = [...new Set(errChars.split(''))].join('');
    return uniqErrChars;
  };

  useEffect(() => {
    if (nds) {
      // Like the NDS submit gate on server-rendered forms: Search stays disabled until every
      // field passes constraint validation.
      setCanSearch(
        [
          validatedAddressFieldRef,
          validatedCityFieldRef,
          validatedStateFieldRef,
          validatedZipCodeFieldRef,
        ].every((fieldRef) => !!fieldRef.current?.validity.valid),
      );
    }
  }, [nds, addressValue, cityValue, stateValue, zipCodeValue]);

  const showContinue = !!(usesErrorComponent && uspsApiError);

  if (nds) {
    const buttonLabel = showContinue
      ? t('in_person_proofing.body.location.po_search.continue_button')
      : t('in_person_proofing.body.location.po_search.search_button');

    return (
      <>
        <div className="auth__form-page-body">
          <div className="stack stack--align-stretch text-left">
            <NDSTextInput
              required
              ref={registerField('address')}
              fieldRef={validatedAddressFieldRef}
              value={addressValue}
              onChange={onAddressChange}
              label={t('in_person_proofing.body.location.po_search.address_label')}
              disabled={disabled}
              maxLength={255}
              pattern="[A-Za-z0-9\-' .\/#]*"
              autoComplete="address-line1"
              messages={{
                patternMismatch: t('in_person_proofing.form.address.errors.unsupported_chars', {
                  char_list: getErroneousAddressChars(),
                }),
              }}
            />
            <NDSTextInput
              required
              ref={registerField('city')}
              fieldRef={validatedCityFieldRef}
              value={cityValue}
              onChange={onCityChange}
              label={t('in_person_proofing.body.location.po_search.city_label')}
              disabled={disabled}
              maxLength={50}
              pattern=".*\S.*$"
              autoComplete="address-level2"
              messages={{ patternMismatch: t('simple_form.required.text') }}
            />
            <ValidatedField ref={validatedStateFieldRef}>
              <SelectInput
                required
                ref={registerField('state')}
                value={stateValue}
                onChange={onStateChange}
                label={t('in_person_proofing.body.location.po_search.state_label')}
                disabled={disabled}
                autoComplete="address-level1"
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
            <NDSTextInput
              required
              ref={registerField('zip_code')}
              fieldRef={validatedZipCodeFieldRef}
              value={zipCodeValue}
              onChange={onZipCodeChange}
              label={t('nds.post_office.search.zipcode_label')}
              disabled={disabled}
              pattern="^\d{5}$"
              maxLength={5}
              minLength={5}
              type="text"
              inputMode="numeric"
              autoComplete="postal-code"
              messages={{ patternMismatch: t('idv.errors.pattern_mismatch.zipcode_five') }}
            />
          </div>
        </div>
        <div className="auth__actions">
          <div className="actions actions--align-stretch">
            <Button
              type="submit"
              className={['usa-button--lg', isLoading && 'usa-button--active']
                .filter(Boolean)
                .join(' ')}
              isDisabled={!showContinue && !canSearch}
              onClick={(event) => {
                if (showContinue) {
                  handleContinue(event);
                } else if (isLoading) {
                  event.preventDefault();
                } else {
                  handleSearch(event);
                }
              }}
            >
              {isLoading ? (
                <>
                  <span className="nds-spinner" aria-hidden="true" />
                  <span className="usa-sr-only">{buttonLabel}</span>
                </>
              ) : (
                buttonLabel
              )}
            </Button>
            <div role="status" className="usa-sr-only">
              {isLoading
                ? t('in_person_proofing.body.location.po_search.is_searching_message')
                : ''}
            </div>
          </div>
        </div>
      </>
    );
  }

  return (
    <>
      <ValidatedField
        ref={validatedAddressFieldRef}
        messages={{
          patternMismatch: t('in_person_proofing.form.address.errors.unsupported_chars', {
            char_list: getErroneousAddressChars(),
          }),
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
          pattern="[A-Za-z0-9\-' .\/#]*"
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
          onClick={usesErrorComponent && uspsApiError ? handleContinue : handleSearch}
          spinOnClick={false}
          actionMessage={t('in_person_proofing.body.location.po_search.is_searching_message')}
          longWaitDurationMs={1}
        >
          {usesErrorComponent && uspsApiError
            ? t('in_person_proofing.body.location.po_search.continue_button')
            : t('in_person_proofing.body.location.po_search.search_button')}
        </SpinnerButton>
      </div>
    </>
  );
}
