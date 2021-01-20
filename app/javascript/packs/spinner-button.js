/**
 * @typedef SpinnerButtonElements
 *
 * @prop {HTMLDivElement} wrapper
 * @prop {HTMLButtonElement|HTMLInputElement|HTMLLinkElement} button
 * @prop {HTMLDivElement?} actionMessage
 */

/**
 * @typedef SpinnerButtonOptions
 *
 * @prop {number} longWaitDurationMs
 */

/** @type {SpinnerButtonOptions} */
const DEFAULT_OPTIONS = {
  longWaitDurationMs: 15000,
};

export class SpinnerButton {
  constructor(wrapper) {
    /** @type {SpinnerButtonElements} */
    this.elements = {
      wrapper,
      button: wrapper.querySelector('a,button:not([type]),[type="submit"],[type="button"]'),
      actionMessage: wrapper.querySelector('.spinner-button__action-message'),
    };

    this.options = {
      ...DEFAULT_OPTIONS,
      ...this.elements.wrapper.dataset,
    };

    this.options.longWaitDurationMs = Number(this.options.longWaitDurationMs);
  }

  bind() {
    this.elements.button.addEventListener('click', () => this.toggleSpinner(true));
    this.elements.wrapper.addEventListener('spinner.start', () => this.toggleSpinner(true));
    this.elements.wrapper.addEventListener('spinner.stop', () => this.toggleSpinner(false));
  }

  /**
   * @param {boolean} isVisible
   */
  toggleSpinner(isVisible) {
    const { wrapper, button, actionMessage } = this.elements;
    wrapper.classList.toggle('spinner-button--spinner-active', isVisible);

    // Avoid setting disabled immediately to allow click event to propagate for form submission.
    setTimeout(() => {
      if (isVisible) {
        button.setAttribute('disabled', '');
      } else {
        button.removeAttribute('disabled');
      }
    }, 0);

    if (actionMessage) {
      actionMessage.textContent = isVisible
        ? /** @type {string} */ (actionMessage.dataset.message)
        : '';
    }

    window.clearTimeout(this.longWaitTimeout);
    if (isVisible) {
      this.longWaitTimeout = window.setTimeout(
        () => this.handleLongWait(),
        this.options.longWaitDurationMs,
      );
    }
  }

  handleLongWait() {
    this.elements.actionMessage?.classList.remove('usa-sr-only');
  }
}

const wrappers = Array.from(document.querySelectorAll('.spinner-button'));
wrappers.forEach((wrapper) => new SpinnerButton(wrapper).bind());
