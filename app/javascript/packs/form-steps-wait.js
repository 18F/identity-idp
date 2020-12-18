import { loadPolyfills } from '@18f/identity-polyfill';

/**
 * @typedef FormStepsWaitElements
 *
 * @prop {HTMLFormElement} form
 */

/**
 * @typedef FormStepsWaitOptions
 *
 * @prop {number} pollIntervalMs Poll interval.
 * @prop {string} waitStepPath URL path to wait step, used in polling.
 */

/** @type {FormStepsWaitOptions} */
const DEFAULT_OPTIONS = {
  pollIntervalMs: 3000,
  waitStepPath: `${window.location.pathname}_wait`,
};

class FormStepsWait {
  constructor(form) {
    /** @type {FormStepsWaitElements} */
    this.elements = { form };

    this.options = {
      ...DEFAULT_OPTIONS,
      ...this.elements.form.dataset,
    };

    this.options.pollIntervalMs = Number(this.options.pollIntervalMs);

    this.bindEvents();
  }

  bindEvents() {
    this.elements.form.addEventListener('submit', (event) => this.handleSubmit(event));
  }

  /**
   * @param {Event} event Form submit event.
   */
  async handleSubmit(event) {
    event.preventDefault();

    const { form } = this.elements;
    const { action, method } = form;

    const response = await window.fetch(action, {
      method,
      body: new window.FormData(form),
    });

    this.handleResponse(response);
  }

  handleResponse(response) {
    const { waitStepPath, pollIntervalMs } = this.options;
    if (!response.ok) {
      // If form submission fails, assume there's a server-side flash error to be shown to the user.
      window.location.reload();
    } else if (response.redirected && new URL(response.url).pathname !== waitStepPath) {
      window.location.href = response.url;
    } else {
      setTimeout(() => this.poll(), pollIntervalMs);
    }
  }

  async poll() {
    const { waitStepPath } = this.options;
    const response = await window.fetch(waitStepPath);
    this.handleResponse(response);
  }
}

loadPolyfills(['fetch']).then(() => {
  [...document.querySelectorAll('[data-form-steps-wait]')].forEach(
    (form) => new FormStepsWait(form),
  );
});
