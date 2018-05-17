// Setting hidden input for intl code
import $ from 'jquery';
import 'intl-tel-input/build/js/utils.js';
import 'intl-tel-input';

// Setting variables that jQuery is using with a $ at the start of the const name
const $telInput = $('#user_phone_form_phone');
const telInput = document.querySelector('#user_phone_form_phone');
const $intlCode = $('#user_phone_form_international_code');

// initialise plugin
$telInput.intlTelInput({
  preferredCountries: ['us', 'ca'],
  excludeCountries: ['io', 'ki', 'nf', 'nr', 'nu', 'sh', 'sx', 'tk', 'wf'],
});

$telInput.on('countrychange', function(e, countryData) {
// Changing hidden dropdown country code on JS dropdown change
  $intlCode.val(countryData.iso2.toUpperCase());

// Using plain JS to dispatch the country change event to phone-internationalization.js
  telInput.dispatchEvent(new Event('countryChange'));
});
