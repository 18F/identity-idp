import { PhoneFormatter, SocialSecurityNumberFormatter, TextField } from 'field-kit';
import DateFormatter from './modules/date-formatter';
import NumericFormatter from './modules/numeric-formatter';
import ZipCodeFormatter from './modules/zip-code-formatter';


function formatForm() {
  const formats = [
    ['.auto_loan', new NumericFormatter()],
    ['.ccn', new NumericFormatter()],
    ['.dob', new DateFormatter()],
    ['.home_equity_line', new NumericFormatter()],
    ['.mfa', new NumericFormatter()],
    ['.mortgage', new NumericFormatter()],
    ['.ssn', new SocialSecurityNumberFormatter()],
    ['[type=tel]', new PhoneFormatter()],
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
