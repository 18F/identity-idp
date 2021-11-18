import { loadPolyfills } from '@18f/identity-polyfill';

/** @typedef {{t:(key:string)=>string, key:(key:string)=>string}} LoginGovI18n */
/** @typedef {{LoginGov:{I18n:LoginGovI18n}}} LoginGovGlobal */

const PATTERN_TYPES = ['personal-key'];

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

/**
 * Returns the error message elements associated with the given input.
 *
 * @param {HTMLInputElement} input Input field.
 *
 * @return {Element[]} Error message elements.
 */
function getInputMessages(input) {
  const messages = [];

  const describedBy = input.getAttribute('aria-describedby');
  if (describedBy) {
    const descriptors = /** @type {Element[]} */ (describedBy
      .split(' ')
      .map((id) => document.getElementById(id))
      .filter(Boolean));

    messages.push(...descriptors);
  }

  /** @type {Element?} */
  let sibling = input;
  while ((sibling = sibling.nextElementSibling)) {
    if (sibling.classList.contains('display-if-invalid')) {
      messages.push(sibling);
    }
  }

  return messages;
}

/**
 * Given an `input` event, updates custom validity of the given input.
 *
 * @param {Event} event Input or invalid event.
 */
function checkInputValidity(event) {
  const input = /** @type {HTMLInputElement} */ (event.target);
  if (input.hasAttribute('data-form-validation-message')) {
    input.setCustomValidity('');
    input.removeAttribute('data-form-validation-message');
  }

  const { I18n } = /** @type {typeof window & LoginGovGlobal} */ (window).LoginGov;
  if (input.validity.valueMissing) {
    input.setCustomValidity(I18n.t('simple_form.required.text'));
    input.setAttribute('data-form-validation-message', '');
  } else if (input.validity.patternMismatch) {
    PATTERN_TYPES.forEach((type) => {
      if (input.classList.contains(type)) {
        // i18n-tasks-use t('idv.errors.pattern_mismatch.personal_key')
        input.setCustomValidity(I18n.t(`idv.errors.pattern_mismatch.${snakeCase(type)}`));
        input.setAttribute('data-form-validation-message', '');
      }
    });
  }
}

/**
 * Given an `input` or `invalid` event, toggles visibility of custom error messages.
 *
 * @param {Event} event Input or invalid event.
 */
function toggleErrorMessages(event) {
  const input = /** @type {HTMLInputElement} */ (event.target);
  const messages = getInputMessages(input);
  const errors = Object.keys(ValidityState.prototype)
    .filter((key) => key !== 'valid')
    .filter((key) => input.validity[key]);
  const activeMessages = errors
    .map((type) => `display-if-invalid--${kebabCase(type)}`)
    .flatMap((className) => messages.filter((message) => message.classList.contains(className)));

  input.setAttribute('aria-invalid', 'false');
  input.classList.remove('usa-input--error');
  messages.forEach((message) => message.classList.remove('display-if-invalid--invalid'));

  const hasActiveMessages = !!activeMessages.length;
  if (event.type === 'invalid' && hasActiveMessages) {
    event.preventDefault();

    input.setAttribute('aria-invalid', 'true');
    input.classList.add('usa-input--error');
    input.focus();

    const firstActiveMessage = activeMessages[0];
    firstActiveMessage.classList.add('display-if-invalid--invalid');
    if (firstActiveMessage.classList.contains('display-if-invalid--custom-error')) {
      firstActiveMessage.textContent = input.validationMessage;
    }
  }
}

/**
 * Binds validation to a given input.
 *
 * @param {HTMLInputElement} input Input element.
 */
function validateInput(input) {
  input.addEventListener('input', checkInputValidity);
  input.addEventListener('input', toggleErrorMessages);
  input.addEventListener('invalid', toggleErrorMessages);
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
