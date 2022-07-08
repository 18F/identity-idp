import { render, unmountComponentAtNode } from 'react-dom';
import { Alert } from '@18f/identity-components';
import { SpinnerButtonElement } from './spinner-button-element';

const DEFAULT_POLL_INTERVAL = 3000;

interface AsyncResponse {
  pending?: boolean;

  redirect_url?: string;

  error?: string;
}

class AsyncButtonElement extends HTMLElement {
  #pollTimeout: number;

  connectedCallback(): void {
    this.addEventListener('click', (event) => this.onClick(event));
  }

  disconnectedCallback() {
    window.clearTimeout(this.#pollTimeout);
  }

  get alertTarget(): HTMLElement | null {
    const id = this.getAttribute('alert-target');
    return id ? this.ownerDocument.getElementById(id) : null;
  }

  get form(): HTMLFormElement {
    return this.querySelector('form')!;
  }

  get pollInterval(): number {
    return Number(this.getAttribute('poll-interval')) || DEFAULT_POLL_INTERVAL;
  }

  get unhandledErrorMessage(): string {
    return this.getAttribute('unhandled-error-message')!;
  }

  get spinnerButton(): SpinnerButtonElement {
    return this.querySelector('lg-spinner-button')!;
  }

  onClick(event: Event) {
    if (event.target !== this.spinnerButton.elements.button) {
      return;
    }

    event.preventDefault();

    // Clear error, if present.
    this.renderError(null);

    this.submit();
  }

  /**
   * Submits the form, emulated using global fetch.
   */
  async submit() {
    const { action, method } = this.form;
    const response = await window.fetch(action, { method, body: new window.FormData(this.form) });
    this.handleResponse(response);
  }

  async handleResponse(response) {
    if (response.status >= 500) {
      this.renderError(this.unhandledErrorMessage);
      this.spinnerButton.toggleSpinner(false);
    } else {
      const { pending, error, redirect_url: redirectURL }: AsyncResponse = await response.json();

      if (pending) {
        this.scheduleSubmit();
      } else if (error) {
        this.renderError(error);
        this.spinnerButton.toggleSpinner(false);
      } else if (redirectURL) {
        window.location.href = redirectURL;
      }
    }
  }

  scheduleSubmit() {
    this.#pollTimeout = window.setTimeout(() => this.submit(), this.pollInterval);
  }

  renderError(message: string | null) {
    if (!this.alertTarget) {
      return;
    }

    if (message) {
      render(
        <Alert type="error" className="margin-bottom-4">
          {message}
        </Alert>,
        this.alertTarget,
      );
    } else {
      unmountComponentAtNode(this.alertTarget);
    }
  }
}

if (!customElements.get('lg-async-button')) {
  customElements.define('lg-async-button', AsyncButtonElement);
}

export default AsyncButtonElement;
