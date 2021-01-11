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

/**
 * Returns trimmed content from HTML for given DOM selector, or null if the element does not exist.
 *
 * @param {string} html HTML markup.
 * @param {string} selector DOM selector to retrieve.
 *
 * @return {string?} Trimmed content, if exists.
 */
export function getContentFromHTML(html, selector) {
  const dom = document.implementation.createHTMLDocument();
  dom.body.innerHTML = html;
  const textContent = dom.querySelector(selector)?.textContent;
  return textContent ? textContent.trim() : null;
}

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

  /**
   * @param {Response} response
   */
  async handleResponse(response) {
    const { waitStepPath, pollIntervalMs } = this.options;
    const responseURL = new URL(response.url);

    if (response.status >= 500) {
      this.stopSpinner();

      const { errorMessage } = this.options;
      if (errorMessage) {
        this.renderError(errorMessage);
      }
    } else if (response.redirected && responseURL.pathname !== waitStepPath) {
      let message;
      if (responseURL.pathname === window.location.pathname) {
        const body = await response.text();
        message = getContentFromHTML(body, '.usa-alert.usa-alert--error');
      }

      if (message) {
        this.renderError(message);
        this.stopSpinner();
      } else {
        window.location.href = response.url;
      }
    } else {
      setTimeout(() => this.poll(), pollIntervalMs);
    }
  }

  /**
   * @param {string} message Error message text.
   */
  renderError(message) {
    const errorRoot = document.createElement('div');
    this.elements.form.appendChild(errorRoot);

    render(
      <Alert type="error" className="margin-top-2">
        {message}
      </Alert>,
      errorRoot,
    );
  }

  /**
   * Stops any active spinner buttons associated with this form.
   */
  stopSpinner() {
    const { form } = this.elements;
    const event = new window.CustomEvent('spinner.stop', { bubbles: true });
    // Spinner button may be within the form, or an ancestor. To handle both cases, dispatch a
    // bubbling event on the innermost element that could be associated with a spinner button.
    const target = form.querySelector('.spinner-button--spinner-active') || form;
    target.dispatchEvent(event);
  }

  async poll() {
    const { waitStepPath } = this.options;
    const response = await window.fetch(waitStepPath);
    this.handleResponse(response);
  }
}

loadPolyfills(['fetch', 'custom-event']).then(() => {
  const forms = [...document.querySelectorAll('[data-form-steps-wait]')];
  forms.forEach((form) => new FormStepsWait(form).bind());
});
