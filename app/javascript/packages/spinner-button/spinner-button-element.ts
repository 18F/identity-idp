interface SpinnerButtonElements {
  button: HTMLButtonElement | HTMLInputElement | HTMLLinkElement;

  actionMessage: HTMLElement;
}

/**
 * Default time after which to show action message, in milliseconds.
 */
const DEFAULT_LONG_WAIT_DURATION_MS = 15000;

export class SpinnerButtonElement extends HTMLElement {
  elements: SpinnerButtonElements;

  form: HTMLFormElement | null;

  #longWaitTimeout?: number;

  connectedCallback() {
    this.form = this.querySelector('form') || this.closest('form');

    this.addEventListener('spinner.start', () => this.toggleSpinner(true));
    this.addEventListener('spinner.stop', () => this.toggleSpinner(false));

    if (this.spinOnClick) {
      if (this.form) {
        this.form.addEventListener('submit', this.showSpinner);
      } else {
        this.button.addEventListener('click', this.showSpinner);
      }
    }
  }

  disconnectedCallback() {
    window.clearTimeout(this.#longWaitTimeout);

    if (this.form) {
      this.form.removeEventListener('submit', this.showSpinner);
    } else {
      this.button.removeEventListener('click', this.showSpinner);
    }
  }

  get button(): HTMLElement {
    return this.querySelector('.usa-button')!;
  }

  get actionMessage(): HTMLElement {
    return this.querySelector('.spinner-button__action-message')!;
  }

  get spinOnClick(): boolean {
    return this.getAttribute('spin-on-click') !== 'false';
  }

  /**
   * Time after which to show action message, in milliseconds.
   */
  get longWaitDurationMs(): number {
    return Number(this.getAttribute('long-wait-duration-ms')) || DEFAULT_LONG_WAIT_DURATION_MS;
  }

  showSpinner = () => this.toggleSpinner(true);

  toggleSpinner(isVisible: boolean) {
    this.classList.toggle('spinner-button--spinner-active', isVisible);
    this.button.classList.toggle('usa-button--active', isVisible);

    if (isVisible) {
      this.button.setAttribute('disabled', '');
    } else {
      this.button.removeAttribute('disabled');
    }

    if (this.actionMessage) {
      this.actionMessage.textContent = isVisible ? this.actionMessage.dataset.message! : '';
    }

    window.clearTimeout(this.#longWaitTimeout);
    if (isVisible) {
      this.#longWaitTimeout = window.setTimeout(
        () => this.handleLongWait(),
        this.longWaitDurationMs,
      );
    }
  }

  handleLongWait() {
    this.actionMessage?.classList.remove('usa-sr-only');
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-spinner-button': SpinnerButtonElement;
  }
}

if (!customElements.get('lg-spinner-button')) {
  customElements.define('lg-spinner-button', SpinnerButtonElement);
}

export default SpinnerButtonElement;
