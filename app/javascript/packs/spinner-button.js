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

    this.bindEvents();
  }

  bindEvents() {
    this.elements.button.addEventListener('click', () => this.showSpinner());
  }

  showSpinner() {
    const { wrapper, button, actionMessage } = this.elements;
    wrapper.classList.add('spinner-button--spinner-active');

    // Avoid setting disabled immediately to allow click event to propagate for form submission.
    setTimeout(() => button.setAttribute('disabled', ''), 0);

    if (actionMessage) {
      actionMessage.textContent = /** @type {string} */ (actionMessage.dataset.message);
    }

    setTimeout(() => this.handleLongWait(), this.options.longWaitDurationMs);
  }

  handleLongWait() {
    this.elements.actionMessage?.classList.remove('usa-sr-only');
  }
}

[...document.querySelectorAll('.spinner-button')].forEach((wrapper) => new SpinnerButton(wrapper));
