import { TextInput } from '@18f/identity-components';
import { useState, useRef, useEffect, useCallback } from 'react';
import { t } from '@18f/identity-i18n';
import ValidatedField from '@18f/identity-validated-field/validated-field';
import SpinnerButton, { SpinnerButtonRefHandle } from '@18f/identity-spinner-button/spinner-button';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import useUspsLocations from './hooks/use-usps-locations';
import type { AddressSearchProps } from './types';
import { snakeCase, formatLocations, transformKeys } from './utils';
import InPersonLocations from './components/in-person-locations';

export { snakeCase, formatLocations, transformKeys, InPersonLocations };

function AddressSearch({
  registerField = () => undefined,
  onFoundAddress = () => undefined,
  onFoundLocations = () => undefined,
  onLoadingLocations = () => undefined,
  onError = () => undefined,
  disabled = false,
  addressSearchURL,
  locationsURL,
}: AddressSearchProps) {
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

export default AddressSearch;
