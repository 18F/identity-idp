import 'intl-tel-input/build/js/utils.js';
import * as intlTelInput from 'intl-tel-input/build/js/intlTelInput';

const telInput = document.querySelector('#new_phone_form_phone');

// initialise plugin
intlTelInput(telInput, {
  preferredCountries: ['us', 'ca'],
  excludeCountries: ['io', 'ki', 'nf', 'nr', 'nu', 'sh', 'sx', 'tk', 'wf'],
});

// OnChange event
telInput.addEventListener('countrychange', function() {
  // Using plain JS to dispatch the country change event to phone-internationalization.js
  telInput.dispatchEvent(new Event('countryChange'));
});

function intlTelInputNormalize() {
  // remove duplacte items in the country list
  const dupUsOption = document.querySelectorAll('#country-listbox #iti-item-us')[1];
  if (dupUsOption) {
    dupUsOption.parentNode.removeChild(dupUsOption);
  }
  const dupCanOption = document.querySelectorAll('#country-listbox #iti-item-ca')[1];
  if (dupCanOption) {
    dupCanOption.parentNode.removeChild(dupCanOption);
  }
  // set accessibility label
  const flagContainer = document.querySelectorAll('.flag-container');
  if (flagContainer) {
    [].slice.call(flagContainer).forEach((element) => {
      element.setAttribute('aria-label', 'Country code');
    });
  }
  // fix knapsack error where aria-owns requires aria-expanded, use pop-up instead
  const selectedFlag = document.querySelectorAll('.flag-container .selected-flag');
  if (selectedFlag) {
    [].slice.call(selectedFlag).forEach((element) => {
      element.setAttribute('aria-haspopup', 'true');
      element.setAttribute('role', 'button');
      element.removeAttribute('aria-owns');
    });
  }
}

document.addEventListener('DOMContentLoaded', intlTelInputNormalize);
