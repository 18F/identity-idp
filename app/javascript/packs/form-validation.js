import { loadPolyfills } from '@18f/identity-polyfill';

/** @typedef {{t:(key:string)=>string, key:(key:string)=>string}} LoginGovI18n */
/** @typedef {{LoginGov:{I18n:LoginGovI18n}}} LoginGovGlobal */

const PATTERN_TYPES = ['personal-key', 'ssn', 'zipcode'];

const snakeCase = (string) => string.replace(/[ -]/g, '_').replace(/\W/g, '').toLowerCase();

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

function kebabCase(string) {
  return string.replace(/(.)([A-Z])/g, '$1-$2').toLowerCase();
}

function resetInput(input) {
  input.setCustomValidity('');
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
    const errors = Object.keys(ValidityState.prototype)
      .filter((key) => key !== 'valid')
      .filter((key) => input.validity[key]);

    input.setAttribute('aria-invalid', errors.length ? kebabCase(errors[0]) : 'false');
    input.classList.add('usa-input--error');
    input.focus();
  }

  const { I18n } = /** @type {typeof window & LoginGovGlobal} */ (window).LoginGov;
  if (input.validity.valueMissing) {
    input.setCustomValidity(I18n.t('simple_form.required.text'));
  } else if (input.validity.patternMismatch) {
    PATTERN_TYPES.forEach((type) => {
      if (input.classList.contains(type)) {
        // i18n-tasks-use t('idv.errors.pattern_mismatch.personal_key')
        // i18n-tasks-use t('idv.errors.pattern_mismatch.ssn')
        // i18n-tasks-use t('idv.errors.pattern_mismatch.zipcode')
        input.setCustomValidity(I18n.t(`idv.errors.pattern_mismatch.${snakeCase(type)}`));
      }
    });
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

loadPolyfills(['classlist']).then(() => {
  /** @type {HTMLFormElement[]} */
  const forms = Array.from(document.querySelectorAll('form[data-validate]'));

  forms.forEach(initialize);
});
