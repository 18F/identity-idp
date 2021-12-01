/**
 * Set of text-like input types, used in determining whether the width of the error message should
 * be constrained to match the width of the input.
 *
 * @type {Set<String>}
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

export class ValidatedField extends HTMLElement {
  /** @type {Partial<ValidityState>} */
  errorStrings = {};

  connectedCallback() {
    /** @type {HTMLInputElement?} */
    this.input = this.querySelector('.validated-field__input');
    /** @type {HTMLElement?} */
    this.errorMessage = this.querySelector('.usa-error-message');
    this.descriptorId = this.input?.getAttribute('aria-describedby');
    try {
      Object.assign(
        this.errorStrings,
        JSON.parse(this.querySelector('.validated-field__error-strings')?.textContent || ''),
      );
    } catch {}

    this.input?.addEventListener('input', () => this.setErrorMessage());
    this.input?.addEventListener('invalid', (event) => this.toggleErrorMessage(event));
  }

  /**
   * Handles an invalid event, rendering or hiding an error message based on the input's current
   * validity.
   *
   * @param {Event} event Invalid event.
   */
  toggleErrorMessage(event) {
    event.preventDefault();
    this.setErrorMessage(this.getNormalizedValidationMessage(this.input));
  }

  /**
   * Renders the given message as an error, if present. Otherwise, hides any visible error message.
   *
   * @param {string?=} message Error message to show, or empty to hide.
   */
  setErrorMessage(message) {
    if (message) {
      this.getOrCreateErrorMessageElement().textContent = message;
      this.input?.focus();
    } else if (this.errorMessage) {
      this.removeChild(this.errorMessage);
      this.errorMessage = null;
    }

    this.input?.classList.toggle('usa-input--error', !!message);
  }

  /**
   * Returns a validation message for the given input, normalized to use customized error strings.
   * An empty string is returned for a valid input.
   *
   * @param {HTMLInputElement?=} input Input element.
   *
   * @return {string} Validation message.
   */
  getNormalizedValidationMessage(input) {
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
   * @returns {Element} Error message element.
   */
  getOrCreateErrorMessageElement() {
    if (!this.errorMessage) {
      this.errorMessage = this.ownerDocument.createElement('div');
      this.errorMessage.classList.add('usa-error-message');
      if (this.descriptorId) {
        this.errorMessage.id = this.descriptorId;
      }
      if (this.input && TEXT_LIKE_INPUT_TYPES.has(this.input.type)) {
        this.errorMessage.style.maxWidth = `${this.input.offsetWidth}px`;
      }

      this.appendChild(this.errorMessage);
    }

    return this.errorMessage;
  }
}
