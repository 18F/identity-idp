import 'intl-tel-input/build/js/utils.js';
import * as intlTelInput from 'intl-tel-input/build/js/intlTelInput';

const telInput = document.querySelector('#new_phone_form_phone');
const intlCode = document.querySelector('#new_phone_form_international_code');

// initialise plugin
intlTelInput(telInput, {
  preferredCountries: ['us', 'ca'],
  excludeCountries: ['io', 'ki', 'nf', 'nr', 'nu', 'sh', 'sx', 'tk', 'wf'],
});

// OnChange event
telInput.addEventListener('countrychange', function() {
  const selected = document.querySelector(".iti__country[aria-selected='true']");
  const country = selected.getAttribute('data-country-code').toUpperCase();
  // update international_code dropdown
  for (let i = 0; i < intlCode.options.length; i += 1) {
    if (intlCode.options[i].value === country) {
      intlCode.options[i].selected = true;
    }
  }
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

document.addEventListener('DOMContentLoaded', intlTelInputNormalize);
