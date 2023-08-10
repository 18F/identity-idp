import { Alert, TextInput, PageHeading } from '@18f/identity-components';
import { useState, useRef, useEffect, useCallback } from 'react';
import { t } from '@18f/identity-i18n';
import ValidatedField from '@18f/identity-validated-field/validated-field';
import SpinnerButton, { SpinnerButtonRefHandle } from '@18f/identity-spinner-button/spinner-button';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import InPersonLocations from './in-person-locations';
import type {
  AddressSearchProps,
  AddressSearchInputProps,
  FormattedLocation,
  LocationQuery,
} from '../types';
import useUspsLocations from '../hooks/use-usps-locations';

export function AddressSearchInput({
  registerField = () => undefined,
  onFoundAddress = () => undefined,
  onFoundLocations = () => undefined,
  onLoadingLocations = () => undefined,
  onError = () => undefined,
  disabled = false,
  addressSearchURL,
  locationsURL,
}: AddressSearchInputProps) {
  const spinnerButtonRef = useRef<SpinnerButtonRefHandle>(null);
  const [textInput, setTextInput] = useState('');
  const {
    locationResults,
    uspsError,
    addressError,
    isLoading,
    handleAddressSearch: onSearch,
    foundAddress,
    validatedFieldRef,
  } = useUspsLocations({ locationsURL, addressSearchURL });

  const onTextInputChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const { target } = event;
    setTextInput(target.value);
  };

  useEffect(() => {
    spinnerButtonRef.current?.toggleSpinner(isLoading);
    onLoadingLocations(isLoading);
  }, [isLoading]);

  useEffect(() => {
    addressError && onError(addressError);
    uspsError && onError(uspsError);
  }, [uspsError, addressError]);

  useDidUpdateEffect(() => {
    onFoundLocations(locationResults);

    foundAddress && onFoundAddress(foundAddress);
  }, [locationResults]);

  const handleSearch = useCallback(
    (event) => {
      onError(null);
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

function AddressSearch({
  disabled = false,
  registerField,
  handleLocationSelect: onSelect,
  handleFoundLocations: onFoundLocations,
  locationsURL,
  addressSearchURL,
}: AddressSearchProps) {
  const [isLoadingLocations, setLoadingLocations] = useState<boolean>(false);
  const [locationResults, setLocationResults] = useState<FormattedLocation[] | null | undefined>(
    null,
  );
  const [foundAddress, setFoundAddress] = useState<LocationQuery | null>(null);
  const [apiError, setApiError] = useState<Error | null>(null);

  return (
    <>
      {apiError && (
        <Alert type="error" className="margin-bottom-4">
          {t('idv.failure.exceptions.post_office_search_error')}
        </Alert>
      )}
      <PageHeading>{t('in_person_proofing.headings.po_search.location')}</PageHeading>
      <p>{t('in_person_proofing.body.location.po_search.po_search_about')}</p>
      <AddressSearchInput
        registerField={registerField}
        onFoundAddress={setFoundAddress}
        onFoundLocations={(locations) => {
          setLocationResults(locations);
          onFoundLocations && onFoundLocations(locations);
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
          onSelect={onSelect}
          address={foundAddress?.address || ''}
        />
      )}
    </>
  );
}

export default AddressSearch;
