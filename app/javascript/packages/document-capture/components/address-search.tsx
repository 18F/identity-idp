import { TextInput } from '@18f/identity-components';
import { useState, useRef, useEffect, RefObject } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import ValidatedField from '@18f/identity-validated-field/validated-field';
import SpinnerButton, { SpinnerButtonRefHandle } from '@18f/identity-spinner-button/spinner-button';
import type { RegisterFieldCallback } from '@18f/identity-form-steps';

interface AddressSearchProps {
  onSearch?: (
    event: MouseEvent,
    textInput: string,
    fieldValidationRef: RefObject<HTMLFormElement> | undefined,
  ) => void;
  registerField?: RegisterFieldCallback;
  loading?: boolean;
}

export const ADDRESS_SEARCH_URL = '/api/addresses';

function AddressSearch({
  registerField = () => undefined,
  onSearch = () => {},
  loading = false,
}: AddressSearchProps) {
  const { t } = useI18n();
  const spinnerButtonRef = useRef<SpinnerButtonRefHandle>(null);
  const validatedFieldRef = useRef<HTMLFormElement>(null);
  const [unvalidatedAddressInput, setUnvalidatedAddressInput] = useState('');

  function onAddressChanged(event) {
    const target = event.target as HTMLInputElement;
    setUnvalidatedAddressInput(target.value);
  }

  useEffect(() => {
    spinnerButtonRef.current?.toggleSpinner(loading);
  }, [loading]);

  function handleSearch(event) {
    onSearch(event, unvalidatedAddressInput, validatedFieldRef);
  }

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
          value={unvalidatedAddressInput}
          onChange={onAddressChanged}
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
      >
        {t('in_person_proofing.body.location.po_search.search_button')}
      </SpinnerButton>
    </>
  );
}

export default AddressSearch;
