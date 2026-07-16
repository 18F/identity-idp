import { bindFormSubmitters } from './form-submitters';

const FORM_VALIDATION_READY = 'adsFormValidationReady';
const ERROR_INNER_CLASS = 'ads-input__error-inner';
const VISIBLE_ERROR_CLASS = 'ads-input__error--visible';

type ValidatedControl = HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement;

const validationControls = (form: HTMLFormElement) =>
  Array.from(
    form.querySelectorAll<ValidatedControl>('.ads-input__control, .validated-field__input'),
  );

const submitterSkipsValidation = (event: SubmitEvent) => {
  const { submitter } = event;

  return (
    (submitter instanceof HTMLButtonElement || submitter instanceof HTMLInputElement) &&
    submitter.formNoValidate
  );
};

const bindFormValidation = (form: HTMLFormElement) => {
  bindFormSubmitters(form);

  if (form.dataset[FORM_VALIDATION_READY] === 'true') {
    return;
  }

  form.dataset[FORM_VALIDATION_READY] = 'true';
  form.noValidate = true;
  form.addEventListener('submit', (event) => {
    if (submitterSkipsValidation(event)) {
      return;
    }

    if (form.checkValidity()) {
      return;
    }

    event.preventDefault();
    validationControls(form)
      .find((control) => !control.validity.valid)
      ?.focus();
  });
};

class ValidatedFieldElement extends HTMLElement {
  input: ValidatedControl | null;

  inputWrapper: HTMLElement | null;

  errorMessage: HTMLElement | null;

  isCheckingValidity = false;

  connectedCallback() {
    this.input = this.querySelector<ValidatedControl>('.validated-field__input');
    this.inputWrapper = this.querySelector('.validated-field__input-wrapper');
    this.errorMessage = this.ownerDocument.getElementById(this.errorId);
    this.normalizeExistingErrorMessage();
    this.input?.addEventListener('input', () => this.setErrorMessage());
    this.input?.addEventListener('input', () => this.setInputIsValid(true));
    this.input?.addEventListener('change', () => this.setErrorMessage());
    this.input?.addEventListener('change', () => this.setInputIsValid(true));
    this.input?.addEventListener('blur', () => this.validate({ checkValidity: true }));
    this.input?.addEventListener('invalid', (event) => this.toggleErrorMessage(event));
    if (this.input?.form) {
      bindFormValidation(this.input.form);
    }
  }

  get errorStrings(): Partial<ValidityState> {
    try {
      return JSON.parse(this.querySelector('.validated-field__error-strings')?.textContent || '');
    } catch {
      return {};
    }
  }

  get errorId(): string {
    return this.getAttribute('error-id')!;
  }

  get descriptorIdRefs(): string[] {
    return this.input?.getAttribute('aria-describedby')?.split(' ').filter(Boolean) || [];
  }

  get isValid(): boolean {
    return this.input?.getAttribute('aria-invalid') !== 'true';
  }

  /**
   * Handles an invalid event, rendering or hiding an error message based on the input's current
   * validity.
   *
   * @param event Invalid event.
   */
  toggleErrorMessage(event: Event) {
    event.preventDefault();
    this.validate({ focus: !this.isCheckingValidity });
  }

  validate({ focus = false, checkValidity = false } = {}) {
    if (checkValidity && this.input && !this.isCheckingValidity) {
      this.isCheckingValidity = true;
      try {
        this.input.checkValidity();
      } finally {
        this.isCheckingValidity = false;
      }
    }

    const errorMessage = this.getNormalizedValidationMessage(this.input);
    const isValid = !errorMessage;

    this.setErrorMessage(errorMessage);
    if (focus) {
      this.focusOnError(isValid);
    }
    this.setInputIsValid(isValid);

    return isValid;
  }

  /**
   * Renders the given message as an error, if present. Otherwise, hides any visible error message.
   *
   * @param message Error message to show, or empty to hide.
   */
  setErrorMessage(message?: string | null) {
    if (message) {
      this.getOrCreateErrorMessageElement();
      this.ensureErrorInner(this.errorMessage!).textContent = message;
      this.errorMessage!.classList.add(VISIBLE_ERROR_CLASS);
      this.errorMessage!.classList.remove('display-none');
      this.errorMessage!.hidden = false;
    } else if (this.errorMessage) {
      this.ensureErrorInner(this.errorMessage).textContent = '';
      this.errorMessage.classList.remove(VISIBLE_ERROR_CLASS);
      this.errorMessage.hidden = true;
    }
  }

  private ensureErrorInner(error: HTMLElement) {
    let inner = error.querySelector<HTMLElement>(`.${ERROR_INNER_CLASS}`);
    if (inner) {
      return inner;
    }

    inner = this.ownerDocument.createElement('span');
    inner.className = ERROR_INNER_CLASS;
    if (error.textContent) {
      inner.textContent = error.textContent;
      error.textContent = '';
    }
    error.appendChild(inner);
    return inner;
  }

  private normalizeExistingErrorMessage() {
    if (!this.errorMessage) {
      return;
    }

    const inner = this.ensureErrorInner(this.errorMessage);
    const hasText = (inner.textContent?.trim().length ?? 0) > 0;
    this.errorMessage.classList.toggle(VISIBLE_ERROR_CLASS, hasText);
    this.errorMessage.classList.toggle('display-none', !hasText);
    this.errorMessage.hidden = !hasText;
  }

  /**
   * Sets input attributes corresponding to given validity state.
   *
   * @param isValid Whether input is valid.
   */
  setInputIsValid(isValid: boolean) {
    if (isValid === this.isValid) {
      return;
    }

    this.input?.setAttribute('aria-invalid', String(!isValid));

    const idRefs = this.descriptorIdRefs.filter((idRef) => idRef !== this.errorId);
    if (!isValid) {
      idRefs.push(this.errorId);
    }
    if (idRefs.length) {
      this.input?.setAttribute('aria-describedby', idRefs.join(' '));
    } else {
      this.input?.removeAttribute('aria-describedby');
    }
  }

  /**
   * Returns a validation message for the given input, normalized to use customized error strings.
   * An empty string is returned for a valid input.
   *
   * @param input Input element.
   *
   * @return Validation message.
   */
  getNormalizedValidationMessage(input?: ValidatedControl | null): string {
    if (!input || input.validity.valid) {
      return '';
    }

    for (const type in input.validity) {
      if (type !== 'valid' && input.validity[type] && this.errorStrings[type]) {
        return this.errorStrings[type];
      }
    }

    return input.validationMessage;
  }

  /**
   * Returns an error message element. If one doesn't already exist, it is created and appended to
   * the root.
   *
   * @return Error message element.
   */
  getOrCreateErrorMessageElement(): Element {
    if (!this.errorMessage) {
      this.errorMessage = this.ownerDocument.createElement('p');
      this.errorMessage.classList.add('ads-input__error');
      this.errorMessage.id = this.errorId;
      this.errorMessage.setAttribute('aria-live', 'polite');
      const inner = this.ownerDocument.createElement('span');
      inner.className = ERROR_INNER_CLASS;
      this.errorMessage.appendChild(inner);
      this.inputWrapper?.appendChild(this.errorMessage);
    }

    return this.errorMessage;
  }

  /**
   * Focus on this input if it's invalid and another error element
   * does not have focus.
   *
   * @param isValid Whether input is valid.
   */
  private focusOnError(isValid: boolean) {
    if (!isValid && document.activeElement?.getAttribute('aria-invalid') !== 'true') {
      this.input?.focus();
    }
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-validated-field': ValidatedFieldElement;
  }
}

if (!customElements.get('lg-validated-field')) {
  customElements.define('lg-validated-field', ValidatedFieldElement);
}

export default ValidatedFieldElement;
