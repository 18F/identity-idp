import 'classlist.js';
import h5f from 'h5f';


const validate = {
  msgs: {
    missing: 'Please fill in all required fields.',
    mismatch: 'Please match the requested format.',
  },

  init() {
    this.form = document.querySelector('form');
    if (!this.form) return;
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
    this.form.addEventListener('invalid', e => e.preventDefault(), true);
    this.form.addEventListener('change', e => this.validateField(e.target));
    this.form.addEventListener('submit', e => this.submitForm(e));
    this.btn.addEventListener('click', () => this.validateForm());
  },

  submitForm(e) {
    if (!this.form.checkValidity()) e.preventDefault();
  },

  validateForm() {
    const fields = this.form.querySelectorAll('.field');
    for (let i = 0; i < fields.length; i++) {
      this.validateField(fields[i]);
    }

    // add focus to first invalid input
    const invalidField = this.form.querySelector(':invalid');
    if (invalidField) invalidField.focus();
  },

  validateField(f) {
    f.classList.add('interacted');

    const parent = f.parentNode;
    const errorMsg = parent.querySelector('.error-message');

    if (errorMsg !== null) parent.removeChild(errorMsg);

    if (!f.validity.valid) this.addInvalidMarkup(f);
    else this.removeInvalidMarkup(f);
  },

  addInvalidMarkup(f) {
    f.setAttribute('aria-invalid', 'true');
    f.setAttribute('aria-describedby', `alert_${f.id}`);

    if (f.validity.valueMissing) f.setCustomValidity(this.msgs.missing);
    else if (f.validity.typeMismatch) f.setCustomValidity(this.msgs.mismatch);
    else f.setCustomValidity('');

    f.insertAdjacentHTML(
      'afterend',
      `<div role='alert' class='error-message red h5' id='alert_${f.id}'>
        ${f.validationMessage}
      </div>`
    );
  },

  removeInvalidMarkup(f) {
    f.removeAttribute('aria-invalid');
    f.removeAttribute('aria-describedby');
  },
};


document.addEventListener('DOMContentLoaded', () => validate.init());
