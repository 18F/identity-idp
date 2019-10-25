import 'intl-tel-input/build/js/utils.js';
import * as intlTelInput from 'intl-tel-input/build/js/intlTelInput';

const telInput = document.querySelector('#new_phone_form_phone');
intlTelInput(telInput);

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
