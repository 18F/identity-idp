import { t } from '@18f/identity-i18n';

/**
 * Given a submit event, disables all submit buttons within the target form.
 *
 * @param event Submit event.
 */
function disableFormSubmit(event: Event) {
  const form = event.target as HTMLFormElement;
  Array.from(form.querySelectorAll(['button:not([type])', '[type="submit"]'].join())).forEach(
    (element) => {
      const submit = element as HTMLInputElement | HTMLButtonElement;
      submit.disabled = true;
      submit.classList.add('usa-button--active');
    },
  );
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
 * @param event Input or invalid event.
 */

function checkInputValidity(event: Event) {
  const input = event.target as HTMLInputElement;
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
 * @param input Input element.
 */
function validateInput(input: HTMLInputElement) {
  input.addEventListener('input', checkInputValidity);
  input.addEventListener('invalid', checkInputValidity);
}

/**
 * Initializes validation on a form element.
 *
 * @param form Form to initialize.
 */
export function initialize(form: HTMLFormElement) {
  const fields: HTMLInputElement[] = Array.from(
    form.querySelectorAll(['.field', '[required]'].join()),
  );
  fields.forEach(validateInput);
  form.addEventListener('submit', disableFormSubmit);
}

const forms: HTMLFormElement[] = Array.from(document.querySelectorAll('form[data-validate]'));
forms.forEach(initialize);
