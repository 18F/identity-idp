import { PhoneFormatter, SocialSecurityNumberFormatter, TextField } from 'field-kit';

import validateField from './validate-field';
import ZipCodeFormatter from './modules/zip-code-formatter';


function formatForm() {
  const formats = [
    ['[type=tel]', new PhoneFormatter()],
    ['.ssn', new SocialSecurityNumberFormatter()],
    ['.zipcode', new ZipCodeFormatter()],
  ];

  formats.forEach(function(f) {
    const [el, formatter] = f;
    const input = document.querySelector(el);
    if (input) {
      /* eslint-disable no-new, no-shadow */
      const field = new TextField(input, formatter);
      // removes focus set by field-kit bug https://github.com/square/field-kit/issues/62
      document.activeElement.blur();
      field.setDelegate({
        textFieldDidEndEditing(field) {
          // prevents IE from thinking empty field has changed
          if (field.element.value !== '') {
            validateField(field.element);
          }
        },
      });
    }
  });
}


document.addEventListener('DOMContentLoaded', formatForm);
