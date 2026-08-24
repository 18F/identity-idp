const FORM_SUBMITTERS_READY = 'ndsFormSubmittersReady';
const IGNORE_BLUR_VALIDATION = 'ndsIgnoreBlurValidation';

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

/** True when blur was caused by activating a disabled submit control. */
export const consumeIgnoreBlurValidation = (form: HTMLFormElement | null | undefined) => {
  if (!form || form.dataset[IGNORE_BLUR_VALIDATION] !== 'true') {
    return false;
  }

  delete form.dataset[IGNORE_BLUR_VALIDATION];
  return true;
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
  // Disabled submitters are not focusable, so blur.relatedTarget is null. Track the
  // mousedown that caused blur so field validation does not treat it as a submit attempt.
  form.addEventListener(
    'mousedown',
    (event) => {
      const { target } = event;
      if (!(target instanceof Element)) {
        delete form.dataset[IGNORE_BLUR_VALIDATION];
        return;
      }

      const submitter = target.closest('button, input');
      const ignore =
        (submitter instanceof HTMLButtonElement || submitter instanceof HTMLInputElement) &&
        submitter.type === 'submit' &&
        submitter.disabled;

      if (ignore) {
        form.dataset[IGNORE_BLUR_VALIDATION] = 'true';
        // Blur runs synchronously during mousedown; clear leftovers after that turn.
        requestAnimationFrame(() => {
          delete form.dataset[IGNORE_BLUR_VALIDATION];
        });
      } else {
        delete form.dataset[IGNORE_BLUR_VALIDATION];
      }
    },
    true,
  );
  sync();
};
