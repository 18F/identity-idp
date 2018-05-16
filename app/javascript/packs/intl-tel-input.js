// Setting hidden input for intl code
import $ from 'jquery';
import intlTelInput from 'intl-tel-input';

const telInput = $('#user_phone_form_phone');
const intlCode = $('#user_phone_form_international_code');

// initialise plugin
telInput.intlTelInput({
  preferredCountries: ['us', 'ca'],
  excludeCountries: ['io', 'ki', 'nf', 'nr', 'nu', 'sh', 'sx', 'tk', 'wf'],
});

// set its initial value
const initialCountry = telInput.intlTelInput('getSelectedCountryData').dialCode;
telInput.val(`+${initialCountry}`);

// inserting country code on dropdown change
telInput.on('countrychange', function(e, countryData) {
  telInput.val(`+${countryData.dialCode}`);
  intlCode.val(countryData.iso2.toUpperCase());
});
