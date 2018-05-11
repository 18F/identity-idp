// Setting hidden input for intl code

const telInput = $('#user_phone_form_phone');
const intlCode = $('#user_phone_form_international_code');

// initialise plugin
telInput.intlTelInput({
  preferredCountries: ['us', 'ca'],
  excludeCountries: ['ag', 'ai', 'as', 'ax', 'bb', 'bl', 'bm', 'bs', 'cc', 'cw', 'cx', 'dm', 'do',
    'eh', 'gd', 'gg', 'gu', 'im', 'io', 'je', 'jm', 'ki', 'kn', 'ky', 'lc', 'mf',
    'mp', 'ms', 'nf', 'nr', 'nu', 'sh', 'sj', 'sx', 'tc', 'tk', 'tl', 'tt',
    'va', 'vc', 'vg', 'vi', 'wf', 'xk'],
});

// set its initial value
const initialCountry = telInput.intlTelInput('getSelectedCountryData').dialCode;
telInput.val(`+${initialCountry}`);

// inserting country code on dropdown change
telInput.on('countrychange', function(e, countryData) {
  telInput.val(`+${countryData.dialCode}`);
  intlCode.val(countryData.iso2.toUpperCase());
});
