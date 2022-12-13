/**
 * Set of text-like input types, used in determining whether the width of the error message should
 * be constrained to match the width of the input.
 */
const TEXT_LIKE_INPUT_TYPES = new Set([
  'date',
  'datetime-local',
  'email',
  'month',
  'number',
  'password',
  'search',
  'tel',
  'text',
  'time',
  'url',
]);

class ValidatedFieldElement extends HTMLElement {
  errorStrings: Partial<ValidityState> = {};

  input: HTMLInputElement | null;

  inputWrapper: HTMLElement | null;

  errorMessage: HTMLElement | null;

  descriptorId?: string | null;

  connectedCallback() {
    this.input = this.querySelector('.validated-field__input');
    this.inputWrapper = this.querySelector('.validated-field__input-wrapper');
    this.descriptorId = this.input?.getAttribute('aria-describedby');
    this.errorMessage = this.getErrorElement();
    try {
      Object.assign(
        this.errorStrings,
        JSON.parse(this.querySelector('.validated-field__error-strings')?.textContent || ''),
      );
    } catch {}

    this.input?.addEventListener('input', () => this.setErrorMessage());
    this.input?.addEventListener('input', () => this.setInputIsValid(true));
    this.input?.addEventListener('invalid', (event) => this.toggleErrorMessage(event));
  }

  /**
   * Handles an invalid event, rendering or hiding an error message based on the input's current
   * validity.
   *
   * @param event Invalid event.
   */
  toggleErrorMessage(event: Event) {
    event.preventDefault();

    const errorMessage = this.getNormalizedValidationMessage(this.input);
    const isValid = !errorMessage;

    this.setErrorMessage(errorMessage);
    this.focusOnError(isValid);
    this.setInputIsValid(isValid);
  }

  /**
   * Renders the given message as an error, if present. Otherwise, hides any visible error message.
   *
   * @param message Error message to show, or empty to hide.
   */
  setErrorMessage(message?: string | null) {
    if (message) {
      this.getOrCreateErrorMessageElement().textContent = message;
      this.showAriaDescribedByError();
      if (this.errorMessage?.style.display === 'none') {
        this.errorMessage.style.display = '';
      }
    } else if (this.errorMessage) {
      this.errorMessage.style.display = 'none';
      this.hideAriaDescribedByError();
    }
  }

  private showAriaDescribedByError() {
    const aria = this.input?.getAttribute('aria-describedby');
    const errorId = this.getAttribute('error-id');
    const ariaContents = aria?.split(/s+/) || [];
    if (errorId && this.input && !ariaContents.includes(errorId)) {
      this.input?.setAttribute('aria-describedby', [...ariaContents, errorId].join(' '));
    }
  }

  private hideAriaDescribedByError() {
    const aria = this.input?.getAttribute('aria-describedby');
    const errorId = this.getAttribute('error-id');
    const ariaContents = aria?.split(/s+/) || [];
    if (errorId && this.input && ariaContents.includes(errorId)) {
      this.input?.setAttribute(
        'aria-describedby',
        ariaContents.filter((e) => e !== errorId).join(' '),
      );
    }
  }

  /**
   * Sets input attributes corresponding to given validity state.
   *
   * @param isValid Whether input is valid.
   */
  setInputIsValid(isValid: boolean) {
    this.input?.classList.toggle('usa-input--error', !isValid);
    this.input?.setAttribute('aria-invalid', String(!isValid));
  }

  /**
   * Returns a validation message for the given input, normalized to use customized error strings.
   * An empty string is returned for a valid input.
   *
   * @param input Input element.
   *
   * @return Validation message.
   */
  getNormalizedValidationMessage(input?: HTMLInputElement | null): string {
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
      this.errorMessage = this.ownerDocument.createElement('div');
      this.errorMessage.classList.add('usa-error-message');

      const errorId = this.getAttribute('error-id');

      const descriptorId = (this.descriptorId?.split(' ') || []).find(
        (id) => document.getElementById(id) === null,
      );

      if (errorId) {
        this.errorMessage.id = errorId;
      }
      if (!errorId && descriptorId) {
        this.errorMessage.id = descriptorId;
      }

      if (this.input && TEXT_LIKE_INPUT_TYPES.has(this.input.type)) {
        this.errorMessage.style.maxWidth = `${this.input.offsetWidth}px`;
      }

      this.inputWrapper?.appendChild(this.errorMessage);
    }

    return this.errorMessage;
  }

  private getErrorElement(): HTMLElement | null {
    const describedByElementIds = this.descriptorId?.split(' ') || [];

    return (
      describedByElementIds
        .map((id) => document.getElementById(id))
        .find((element) => element?.classList.contains('usa-error-message')) ||
      this.querySelector('.usa-error-message')
    );
  }

  /**
   * Focus on this input if it's invalid and another error element
   * does not have focus.
   *
   * @param isValid Whether input is valid.
   */
  private focusOnError(isValid: boolean) {
    if (!isValid && !document.activeElement?.classList.contains('usa-input--error')) {
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
