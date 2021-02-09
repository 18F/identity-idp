/**
 * @typedef PivCacButtonElements
 *
 * @prop {HTMLDivElement} wrapper
 * @prop {HTMLButtonElement|HTMLInputElement|HTMLLinkElement} button
 * @prop {HTMLDivElement?} actionMessage
 */

/**
 * @typedef PivCacButtonOptions
 *
 * @prop {number} longWaitDurationMs
 */

/** @type {PivCacButtonOptions} */
const DEFAULT_OPTIONS = {
  longWaitDurationMs: 15000,
};

export class PivCacButton {
  constructor(wrapper) {
    /** @type {PivCacButtonElements} */
    this.elements = {
      wrapper,
      button: wrapper.querySelector('a,button:not([type]),[type="submit"],[type="button"]'),
      actionMessage: wrapper.querySelector('.piv-cac-button__action-message'),
    };

    this.options = {
      ...DEFAULT_OPTIONS,
      ...this.elements.wrapper.dataset,
    };

    this.options.longWaitDurationMs = Number(this.options.longWaitDurationMs);
  }

  bind() {
    this.elements.button.addEventListener('click', (e) => {
      e.preventDefault();
      this.toggleSpinner(true);

      console.log('Handling PIV/CAC redirects in the background');

      window
        .fetch(`${this.elements.button.href}.json`)
        .then((response) => {
          console.log(`Handling IdP response with status ${response.status}`);
          return response.json();
        })
        .then((data) => {
          console.log(`Redirecting to ${data.redirect_to}`);
          return window.fetch(`${data.redirect_to}&format=json`);
        })
        .then((response) => {
          console.log(`Handling pivcac response with status ${response.status}`);
          return response.json();
        })
        .then((data) => {
          console.log(`Redirecting to ${data.redirect_to}`);

          window.location.href = data.redirect_to;
          return true;
        })
        .catch(() => {
          console.log('Timed out or other error');
          window.location.href = '/login/piv_cac_did_not_work';
          return false;
        });
    });
    this.elements.wrapper.addEventListener('spinner.start', () => this.toggleSpinner(true));
    this.elements.wrapper.addEventListener('spinner.stop', () => this.toggleSpinner(false));
  }

  /**
   * @param {boolean} isVisible
   */
  toggleSpinner(isVisible) {
    const { wrapper, button, actionMessage } = this.elements;
    wrapper.classList.toggle('piv-cac-button--spinner-active', isVisible);

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

const wrappers = Array.from(document.querySelectorAll('.piv-cac-button'));
wrappers.forEach((wrapper) => new PivCacButton(wrapper).bind());
