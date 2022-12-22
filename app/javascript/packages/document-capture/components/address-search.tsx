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
  const [textInput, setTextInput] = useState('');

  function onTextInputChange(event) {
    const target = event.target as HTMLInputElement;
    setTextInput(target.value);
  }

  useEffect(() => {
    spinnerButtonRef.current?.toggleSpinner(loading);
  }, [loading]);

  function handleSearch(event) {
    onSearch(event, textInput, validatedFieldRef);
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
      >
        {t('in_person_proofing.body.location.po_search.search_button')}
      </SpinnerButton>
    </>
  );
}

export default AddressSearch;
