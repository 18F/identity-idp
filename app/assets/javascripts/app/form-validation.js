import 'classlist.js';
import gf from 'gentleform';


function validateForm() {
  const form = document.querySelector('form[novalidate]');

  if (form) {
    gf(form, function onSubmit(e) {
      if (!this.isValid()) e.preventDefault();
    });
  }
}


document.addEventListener('DOMContentLoaded', validateForm);
