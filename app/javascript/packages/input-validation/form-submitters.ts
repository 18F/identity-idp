import type ValidatedFieldElement from '@18f/identity-validated-field/validated-field-element';

const FORM_SUBMITTERS_READY = 'ndsFormSubmittersReady';
const IGNORE_BLUR_VALIDATION = 'ndsIgnoreBlurValidation';
const MEMORABLE_DATE_SELECTOR = 'lg-memorable-date';

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
 * Memorable date errors otherwise render only on submit, which a disabled submitter prevents, so
 * they are shown once focus leaves the date instead.
 */
const showMemorableDateErrors = (memorableDate: Element) => {
  const fields = Array.from(
    memorableDate.querySelectorAll<ValidatedFieldElement>('lg-validated-field'),
  );
  if (!fields.length) {
    return;
  }

  const messages = fields.map((field) => field.getNormalizedValidationMessage(field.input));
  fields.forEach((field, index) => field.setInputIsValid(!messages[index]));
  fields[0].getOrCreateErrorMessageElement().setAttribute('aria-live', 'polite');
  fields[0].setErrorMessage(messages.find(Boolean));
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
  const editedMemorableDates = new WeakSet<Element>();
  const markMemorableDateEdited = ({ target }: Event) => {
    const memorableDate = target instanceof Element && target.closest(MEMORABLE_DATE_SELECTOR);
    if (memorableDate) {
      editedMemorableDates.add(memorableDate);
    }
  };
  form.addEventListener('input', sync);
  form.addEventListener('change', sync);
  form.addEventListener('input', markMemorableDateEdited);
  form.addEventListener('change', markMemorableDateEdited);
  // Untouched empty dates stay quiet on focusout so a layout shift can't make a click below miss.
  form.addEventListener('focusout', (event) => {
    const { target, relatedTarget } = event;
    const memorableDate = target instanceof Element && target.closest(MEMORABLE_DATE_SELECTOR);
    if (
      !memorableDate ||
      (relatedTarget instanceof Node && memorableDate.contains(relatedTarget))
    ) {
      return;
    }

    const isEmpty = Array.from(
      memorableDate.querySelectorAll<HTMLInputElement>('.validated-field__input'),
    ).every((input) => !input.value);
    if (isEmpty && !editedMemorableDates.has(memorableDate)) {
      return;
    }

    showMemorableDateErrors(memorableDate);
  });
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
