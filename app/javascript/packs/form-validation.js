import { t } from '@18f/identity-i18n';

/**
 * Given a submit event, disables all submit buttons within the target form.
 *
 * @param {Event} event Submit event.
 */
function disableFormSubmit(event) {
  const form = /** @type {HTMLFormElement} */ (event.target);
  Array.from(form.querySelectorAll('button:not([type]),[type="submit"]')).forEach((submit) => {
    /** @type {HTMLInputElement|HTMLButtonElement} */ (submit).disabled = true;
  });
}

function resetInput(input) {
  if (input.hasAttribute('data-form-validation-message')) {
    input.setCustomValidity('');
    input.removeAttribute('data-form-validation-message');
  }
  input.setAttribute('aria-invalid', 'false');
  input.classList.remove('usa-input--error');
}

/**
 * Given an `input` or `invalid` event, updates custom validity of the given input.
 *
 * @param {Event} event Input or invalid event.
 */

function checkInputValidity(event) {
  const input = /** @type {HTMLInputElement} */ (event.target);
  resetInput(input);
  if (
    event.type === 'invalid' &&
    !input.validity.valid &&
    input.parentNode?.querySelector('.display-if-invalid')
  ) {
    event.preventDefault();
    input.setAttribute('aria-invalid', 'true');
    input.classList.add('usa-input--error');
    input.focus();
  }

  if (input.validity.valueMissing) {
    input.setCustomValidity(t('simple_form.required.text'));
    input.setAttribute('data-form-validation-message', '');
  }
}

/**
 * Binds validation to a given input.
 *
 * @param {HTMLInputElement} input Input element.
 */
function validateInput(input) {
  input.addEventListener('input', checkInputValidity);
  input.addEventListener('invalid', checkInputValidity);
}

/**
 * Initializes validation on a form element.
 *
 * @param {HTMLFormElement} form Form to initialize.
 */
export function initialize(form) {
  /** @type {HTMLInputElement[]} */
  const fields = Array.from(form.querySelectorAll('.field,[required]'));
  fields.forEach(validateInput);
  form.addEventListener('submit', disableFormSubmit);
}

/** @type {HTMLFormElement[]} */
const forms = Array.from(document.querySelectorAll('form[data-validate]'));
forms.forEach(initialize);
