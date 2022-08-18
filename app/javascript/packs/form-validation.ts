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

/**
 * Initializes validation on a form element.
 *
 * @param form Form to initialize.
 */
export function initialize(form: HTMLFormElement) {
  form.addEventListener('submit', disableFormSubmit);
}

const forms: HTMLFormElement[] = Array.from(document.querySelectorAll('form[data-validate]'));
forms.forEach(initialize);
