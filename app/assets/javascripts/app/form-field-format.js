import { SocialSecurityNumberFormatter, TextField } from 'field-kit';
import DateFormatter from './modules/date-formatter';
import InternationalPhoneFormatter from './modules/international-phone-formatter';
import NumericFormatter from './modules/numeric-formatter';
import PersonalKeyFormatter from './modules/personal-key-formatter';
import USPhoneFormatter from './modules/us-phone-formatter';
import ZipCodeFormatter from './modules/zip-code-formatter';


function formatForm() {
  const formats = [
    ['.dob', new DateFormatter()],
    ['.mfa', new NumericFormatter()],
    ['.phone', new InternationalPhoneFormatter()],
    ['.us-phone', new USPhoneFormatter()],
    ['.personal-key', new PersonalKeyFormatter()],
    ['.ssn', new SocialSecurityNumberFormatter()],
    ['.zipcode', new ZipCodeFormatter()],
  ];

  formats.forEach(function(f) {
    const [el, formatter] = f;
    const input = document.querySelector(el);
    if (input) {
      /* eslint-disable no-new, no-shadow */
      const field = new TextField(input, formatter);

      // add date format placeholders only to .dob fields
      if (el === '.dob') {
        field.setFocusedPlaceholder('');
        field.setUnfocusedPlaceholder('mm/dd/yyyy');
      }

      // removes focus set by field-kit bug https://github.com/square/field-kit/issues/62
      if (el !== '.mfa') document.activeElement.blur();
    }
  });
}


document.addEventListener('DOMContentLoaded', formatForm);
