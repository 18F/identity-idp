import h5f from 'h5f';

import validateField from './validate-field';


const validate = {
  init() {
    this.form = document.querySelector('form');
    if (!this.form) return;
    this.form.noValidate = true;
    this.btn = this.form.querySelector('[type=submit]');

    h5f.setup(this.form, {
      validClass: 'valid',
      invalidClass: 'invalid',
      requiredClass: 'required',
      placeholderClass: 'placeholder',
    });

    this.addEvents();
  },

  addEvents() {
    this.form.addEventListener('change', e => validateField(e.target));
    this.form.addEventListener('submit', e => this.validateForm(e));
  },

  validateForm(e) {
    if (!this.form.checkValidity()) e.preventDefault();

    const fields = this.form.querySelectorAll('.field');
    for (let i = 0; i < fields.length; i++) {
      validateField(fields[i]);
    }

    // add focus to first invalid input
    const invalidField = this.form.querySelector(':invalid');
    if (invalidField) invalidField.focus();
  },
};


document.addEventListener('DOMContentLoaded', () => validate.init());
