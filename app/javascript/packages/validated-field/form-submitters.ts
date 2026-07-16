const FORM_SUBMITTERS_READY = 'adsFormSubmittersReady';

/** Constraint-valid without firing `invalid` (unlike `form.checkValidity()`). */
export const isFormValid = (form: HTMLFormElement) =>
  !Array.from(form.elements).some(
    (element) =>
      (element instanceof HTMLInputElement ||
        element instanceof HTMLSelectElement ||
        element instanceof HTMLTextAreaElement) &&
      element.willValidate &&
      !element.validity.valid,
  );

const isFormSubmitter = (element: Element): element is HTMLButtonElement | HTMLInputElement =>
  (element instanceof HTMLButtonElement || element instanceof HTMLInputElement) &&
  element.type === 'submit' &&
  !element.formNoValidate;

export const syncFormSubmitters = (form: HTMLFormElement) => {
  const disabled = !isFormValid(form);
  for (const element of form.elements) {
    if (isFormSubmitter(element)) {
      element.disabled = disabled;
    }
  }
};

/**
 * Disables form submit buttons until constraint validation requirements are met.
 * Safe to call multiple times; binds once per form.
 */
export const bindFormSubmitters = (form: HTMLFormElement) => {
  if (form.dataset[FORM_SUBMITTERS_READY] === 'true') {
    return;
  }

  form.dataset[FORM_SUBMITTERS_READY] = 'true';
  const sync = () => syncFormSubmitters(form);
  form.addEventListener('input', sync);
  form.addEventListener('change', sync);
  sync();
};
