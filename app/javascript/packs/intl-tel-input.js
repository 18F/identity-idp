// Setting hidden input for intl code

const telInput = $('#user_phone_form_phone');
const intlCode = $('#user_phone_form_international_code');

// initialise plugin
telInput.intlTelInput({
  preferredCountries: ['us', 'ca'],
  excludeCountries: ['as', 'ai', 'ag', 'bs', 'bb', 'bm', 'io', 'vg', 'ky', 'cx', 'cc',
    'cw', 'dm', 'do', 'gd', 'gu', 'gg', 'im', 'jm', 'je', 'ki', 'xk', 'ms', 'nr', 'nu', 'nf', 'mp',
    'bl', 'sh', 'kn', 'lc', 'mf', 'vc', 'sx', 'sj', 'tl', 'tk', 'tt', 'tc', 'vi', 'va', 'wf', 'eh',
    'ax'],
});

// set it's initial value
const initialCountry = telInput.intlTelInput('getSelectedCountryData').dialCode;
telInput.val(`+${initialCountry}`);

// inserting country code on dropdown change
telInput.on('countrychange', function(e, countryData) {
  telInput.val(`+${countryData.dialCode}`);
  intlCode.val(countryData.iso2.toUpperCase());
});
