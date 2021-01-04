import { render } from 'react-dom';
import { Alert } from '@18f/identity-components';
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
 * @prop {string=} errorMessage Message to show on unhandled server error.
 */

/** @type {FormStepsWaitOptions} */
const DEFAULT_OPTIONS = {
  pollIntervalMs: 3000,
  waitStepPath: `${window.location.pathname}_wait`,
};

export class FormStepsWait {
  constructor(form) {
    /** @type {FormStepsWaitElements} */
    this.elements = { form };

    this.options = {
      ...DEFAULT_OPTIONS,
      ...this.elements.form.dataset,
    };

    this.options.pollIntervalMs = Number(this.options.pollIntervalMs);
  }

  bind() {
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
    if (response.status >= 500) {
      this.renderError();
    } else if (response.redirected && new URL(response.url).pathname !== waitStepPath) {
      window.location.href = response.url;
    } else {
      setTimeout(() => this.poll(), pollIntervalMs);
    }
  }

  renderError() {
    // TODO: Assign data-error-message on forms to be picked up here.
    const { errorMessage } = this.options;
    if (errorMessage) {
      const errorRoot = document.createElement('div');
      this.elements.form.prepend(errorRoot);

      render(
        <Alert type="error" className="margin-bottom-4">
          {errorMessage}
        </Alert>,
        errorRoot,
      );

      // TODO: Stop spinner button from spinning.
    }
  }

  async poll() {
    const { waitStepPath } = this.options;
    const response = await window.fetch(waitStepPath, { method: 'HEAD' });
    this.handleResponse(response);
  }
}

loadPolyfills(['fetch']).then(() => {
  const forms = [...document.querySelectorAll('[data-form-steps-wait]')];
  forms.forEach((form) => new FormStepsWait(form).bind());
});
