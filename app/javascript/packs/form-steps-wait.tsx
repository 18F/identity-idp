import { render, unmountComponentAtNode } from 'react-dom';
import { Alert } from '@18f/identity-components';
import { forceRedirect } from '@18f/identity-url';
import type { Navigate } from '@18f/identity-url';

interface FormStepsWaitElements {
  form: HTMLFormElement;
}

interface FormStepsWaitOptions {
  /**
   * Poll interval.
   */
  pollIntervalMs: number;

  /**
   * URL path to wait step, used in polling.
   */
  waitStepPath: string;

  /**
   * Message to show on unhandled server error.
   */
  errorMessage?: string;

  /**
   * DOM selector of HTML element to which alert should render.
   */
  alertTarget?: string;

  /**
   * Optional navigation implementation, useful for stubbing navigation in tests.
   */
  navigate?: Navigate;
}

const DEFAULT_OPTIONS: FormStepsWaitOptions = {
  pollIntervalMs: 3000,
  waitStepPath: `${window.location.pathname}_wait`,
};

/**
 * Returns a DOM document object for given markup string.
 *
 * @param html HTML markup.
 *
 * @return DOM document.
 */
export function getDOMFromHTML(html: string): Document {
  const dom = document.implementation.createHTMLDocument('');
  dom.body.innerHTML = html;
  return dom;
}

/**
 * @return Whether page polls.
 */
export function isPollingPage(dom: Document): boolean {
  return Boolean(dom.querySelector('meta[http-equiv="refresh"]'));
}

/**
 * Returns trimmed page alert contents, if exists.
 *
 * @param dom
 *
 * @return Page alert, if exists.
 */
export function getPageErrorMessage(dom: Document): string | null | undefined {
  return dom.querySelector('.usa-alert.usa-alert--error')?.textContent?.trim();
}

/**
 * Given a response object and its content, returns the redirect destination, which is either the
 * URL from parsed JSON, or the response's own URL.
 *
 * @param response Response object.
 * @param body Body text.
 *
 * @return Redirect destination.
 */
function getRedirectURL(response: Response, body: string): string {
  try {
    const { redirect_url: redirectURL } = JSON.parse(body);
    return redirectURL;
  } catch {
    return response.url;
  }
}

export class FormStepsWait {
  elements: FormStepsWaitElements;

  options: FormStepsWaitOptions;

  constructor(form: HTMLFormElement, options?: Partial<FormStepsWaitOptions>) {
    this.elements = { form };

    this.options = {
      ...DEFAULT_OPTIONS,
      ...this.elements.form.dataset,
      ...options,
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
    // Clear error, if present.
    this.renderError('');

    const response = await fetch(action, {
      method,
      body: new window.FormData(form),
      headers: {
        // Signal to backend that this request is coming from this JS.
        'X-Form-Steps-Wait': '1',
      },
    });

    this.handleResponse(response);
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
        const redirectURL = getRedirectURL(response, body);
        const isSamePage =
          new URL(redirectURL, window.location.href).pathname === window.location.pathname;
        if (message && isSamePage) {
          this.renderError(message);
          this.stopSpinner();
        } else {
          forceRedirect(redirectURL, this.options.navigate);
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
   * Remove any success banners that may be on the page.
   */
  removeSuccessBanner() {
    const successBanner = document.querySelector('.usa-alert.usa-alert--success');
    if (successBanner) {
      successBanner.remove();
    }
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
      this.removeSuccessBanner();
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
    const response = await fetch(waitStepPath, {
      headers: {
        // Signal to backend that this request is coming from this JS.
        'X-Form-Steps-Wait': '1',
      },
    });
    this.handleResponse(response);
  }
}

const forms = Array.from(document.querySelectorAll<HTMLFormElement>('[data-form-steps-wait]'));
forms.forEach((form) => new FormStepsWait(form).bind());
