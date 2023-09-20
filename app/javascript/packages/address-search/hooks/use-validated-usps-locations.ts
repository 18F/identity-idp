import { useState, useRef, useCallback } from 'react';
import { requestUspsLocations } from '@18f/identity-address-search';
import useSWR from 'swr/immutable';
import type { LocationQuery } from '@18f/identity-address-search/types';
import { t } from '@18f/identity-i18n';

export default function useValidatedUspsLocations(locationsURL: string) {
  const [locationQuery, setLocationQuery] = useState<LocationQuery | null>(null);
  const validatedAddressFieldRef = useRef<HTMLFormElement>(null);
  const validatedCityFieldRef = useRef<HTMLFormElement>(null);
  const validatedStateFieldRef = useRef<HTMLFormElement>(null);
  const validatedZipCodeFieldRef = useRef<HTMLFormElement>(null);

  const checkValidityAndDisplayErrors = (address, city, state, zipCode) => {
    let formIsValid = true;
    const zipCodeIsValid = zipCode.length === 5 && !!zipCode.match(/\d{5}/);

    if (address.length === 0) {
      validatedAddressFieldRef.current?.setCustomValidity(t('simple_form.required.text'));
      formIsValid = false;
    } else {
      validatedAddressFieldRef.current?.setCustomValidity('');
    }

    if (city.length === 0) {
      formIsValid = false;
      validatedCityFieldRef.current?.setCustomValidity(t('simple_form.required.text'));
    } else {
      validatedCityFieldRef.current?.setCustomValidity('');
    }

    if (state.length === 0) {
      formIsValid = false;
      validatedStateFieldRef.current?.setCustomValidity(t('simple_form.required.text'));
    } else {
      validatedStateFieldRef.current?.setCustomValidity('');
    }

    if (zipCode.length === 0) {
      formIsValid = false;
      validatedZipCodeFieldRef.current?.setCustomValidity(t('simple_form.required.text'));
    } else {
      validatedZipCodeFieldRef.current?.setCustomValidity('');
    }

    validatedAddressFieldRef.current?.reportValidity();
    validatedCityFieldRef.current?.reportValidity();
    validatedStateFieldRef.current?.reportValidity();
    validatedZipCodeFieldRef.current?.reportValidity();

    return formIsValid && zipCodeIsValid;
  };

  const handleLocationSearch = useCallback(
    (event, addressValue, cityValue, stateValue, zipCodeValue) => {
      event.preventDefault();
      const address = addressValue.trim();
      const city = cityValue.trim();
      const zipCode = zipCodeValue.trim();

      const formIsValid = checkValidityAndDisplayErrors(address, city, stateValue, zipCode);

      if (!formIsValid) {
        return;
      }

      setLocationQuery({
        address: `${address}, ${city}, ${stateValue} ${zipCode}`,
        streetAddress: address,
        city,
        state: stateValue,
        zipCode,
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
