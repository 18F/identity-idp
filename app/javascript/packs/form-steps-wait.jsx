import { render, unmountComponentAtNode } from 'react-dom';
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
 * @prop {string=} alertTarget DOM selector of HTML element to which alert should render.
 */

/** @type {FormStepsWaitOptions} */
const DEFAULT_OPTIONS = {
  pollIntervalMs: 3000,
  waitStepPath: `${window.location.pathname}_wait`,
};

/**
 * Returns a DOM document object for given markup string.
 *
 * @param {string} html HTML markup.
 *
 * @return {Document} DOM document.
 */
export function getDOMFromHTML(html) {
  const dom = document.implementation.createHTMLDocument('');
  dom.body.innerHTML = html;
  return dom;
}

/**
 * @param {Document} dom
 *
 * @return {boolean} Whether page polls.
 */
export function isPollingPage(dom) {
  return Boolean(dom.querySelector('meta[http-equiv="refresh"]'));
}

/**
 * Returns trimmed page alert contents, if exists.
 *
 * @param {Document} dom
 *
 * @return {string?=} Page alert, if exists.
 */
export function getPageErrorMessage(dom) {
  return dom.querySelector('.usa-alert.usa-alert--error')?.textContent?.trim();
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
    this.elements.form.addEventListener('invalid', () => this.stopSpinner(), true);
  }

  /**
   * @param {Event} event Form submit event.
   */
  async handleSubmit(event) {
    event.preventDefault();

    const { form } = this.elements;
    const { action, method } = form;
    // Clear error, if present.
    this.renderError('');

    const response = await window.fetch(action, {
      method,
      body: new window.FormData(form),
    });

    if ('polyfill' in window.fetch) {
      // The fetch polyfill is implemented using XMLHttpRequest, which suffers from an issue where a
      // Content-Type header from a POST is carried into a redirected GET, which is exactly the flow
      // we are handling here. The current version of Rack neither handles nor provides easy insight
      // into an empty-bodied (GET) multi-part form. This will change in Rack 3 with the addition of
      // the Rack::Multipart::EmptyContentError class. In the meantime, only allow non-polyfilled
      // fetch environmnents to handle the initial response.
      //
      // See: https://github.com/whatwg/fetch/issues/609
      // See: https://github.com/rack/rack/issues/1603
      this.poll();
    } else {
      this.handleResponse(response);
    }
  }

  /**
   * @param {Response} response
   */
  async handleResponse(response) {
    if (response.status >= 500) {
      this.handleFailedResponse();
    } else {
      const body = await response.text();
      const dom = getDOMFromHTML(body);
      if (isPollingPage(dom)) {
        this.scheduleNextPollFetch();
      } else {
        const message = getPageErrorMessage(dom);
        const isSamePage = new URL(response.url).pathname === window.location.pathname;
        if (message && isSamePage) {
          this.renderError(message);
          this.stopSpinner();
        } else {
          window.location.href = response.url;
        }
      }
    }
  }

  handleFailedResponse() {
    this.stopSpinner();

    const { errorMessage } = this.options;
    if (errorMessage) {
      this.renderError(errorMessage);
    }
  }

  scheduleNextPollFetch() {
    setTimeout(() => this.poll(), this.options.pollIntervalMs);
  }

  /**
   * @param {string} message Error message text.
   */
  renderError(message) {
    const { alertTarget } = this.options;
    if (!alertTarget) {
      return;
    }

    const errorRoot = document.querySelector(alertTarget);
    if (!errorRoot) {
      return;
    }

    if (message) {
      render(
        <Alert type="error" className="margin-bottom-4">
          {message}
        </Alert>,
        errorRoot,
      );
    } else {
      unmountComponentAtNode(errorRoot);
    }
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
  const forms = Array.from(document.querySelectorAll('[data-form-steps-wait]'));
  forms.forEach((form) => new FormStepsWait(form).bind());
});
