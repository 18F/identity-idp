import { loadPolyfills } from '@18f/identity-polyfill';

/** @typedef {{t:(key:string)=>string, key:(key:string)=>string}} LoginGovI18n */
/** @typedef {{LoginGov:{I18n:LoginGovI18n}}} LoginGovGlobal */

const PATTERN_TYPES = ['dob', 'personal-key', 'ssn', 'state_id_number', 'zipcode'];

/**
 * Given a submit event, disables all submit buttons within the target form.
 *
 * @param {Event} event Submit event.
 */
function disableFormSubmit(event) {
  const form = /** @type {HTMLFormElement} */ (event.target);
  [...form.querySelectorAll('button:not([type]),[type="submit"]')].forEach((submit) => {
    /** @type {HTMLInputElement|HTMLButtonElement} */ (submit).disabled = true;
  });
}

/**
 * Given an `input` or `invalid` event, updates custom validity of the given input.
 *
 * @param {Event} event Input or invalid event.
 */
function checkInputValidity(event) {
  const input = /** @type {HTMLInputElement} */ (event.target);
  input.setCustomValidity('');

  const { I18n } = /** @type {typeof window & LoginGovGlobal} */ (window).LoginGov;

  if (input.validity.valueMissing) {
    input.setCustomValidity(I18n.t('simple_form.required.text'));
  } else if (input.validity.patternMismatch) {
    PATTERN_TYPES.forEach((type) => {
      if (input.classList.contains(type)) {
        input.setCustomValidity(I18n.t(`idv.errors.pattern_mismatch.${I18n.key(type)}`));
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
  /** @type {HTMLInputElement[]} */ ([...form.querySelectorAll('.field')]).forEach(validateInput);
  form.addEventListener('submit', disableFormSubmit);
}

loadPolyfills(['classlist']).then(() => {
  const forms = /** @type {HTMLFormElement[]} */ ([
    ...document.querySelectorAll('form[data-validate]'),
  ]);

  forms.forEach(initialize);
});
