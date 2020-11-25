import { loadPolyfills } from '@18f/identity-polyfill';
import 'intl-tel-input/build/js/utils.js';
import * as intlTelInput from 'intl-tel-input/build/js/intlTelInput';

function intlTelInputNormalize() {
  // remove duplacte items in the country list
  const dupUsOption = document.querySelectorAll('#country-listbox #iti-item-us')[1];
  if (dupUsOption) {
    /** @type {HTMLElement} */ (dupUsOption.parentNode).removeChild(dupUsOption);
  }
  const dupCanOption = document.querySelectorAll('#country-listbox #iti-item-ca')[1];
  if (dupCanOption) {
    /** @type {HTMLElement} */ (dupCanOption.parentNode).removeChild(dupCanOption);
  }
  // set accessibility label
  const flagContainer = document.querySelectorAll('.iti__flag-container');
  if (flagContainer) {
    [].slice.call(flagContainer).forEach((element) => {
      element.setAttribute('aria-label', 'Country code');
    });
  }
  // fix knapsack error where aria-owns requires aria-expanded, use pop-up instead
  const selectedFlag = document.querySelectorAll('.iti__flag-container .iti__selected-flag');
  if (selectedFlag) {
    [].slice.call(selectedFlag).forEach((element) => {
      element.setAttribute('aria-haspopup', 'true');
      element.setAttribute('role', 'button');
      element.removeAttribute('aria-owns');
    });
  }
}

loadPolyfills(['custom-event']).then(() => {
  /** @type {HTMLInputElement?} */
  const telInput = document.querySelector('#new_phone_form_phone');

  /** @type {HTMLSelectElement?} */
  const intlCode = document.querySelector('#new_phone_form_international_code');

  if (!telInput || !intlCode) {
    return;
  }

  /** @type {string[]|undefined} */
  const onlyCountries = intlCode.dataset.countries && JSON.parse(intlCode.dataset.countries);
  const iti = intlTelInput(telInput, { preferredCountries: ['US', 'CA'], onlyCountries });

  // Mirror country change to the hidden select field, which holds the value for form submission.
  telInput.addEventListener('countrychange', function () {
    /** @type {{iso2?:string}} */
    const country = iti.getSelectedCountryData();
    if (country.iso2) {
      intlCode.value = country.iso2.toUpperCase();
      intlCode.dispatchEvent(new CustomEvent('change'));
    }
  });

  intlTelInputNormalize();
});
