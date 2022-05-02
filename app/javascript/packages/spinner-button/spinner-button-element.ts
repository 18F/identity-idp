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

  #longWaitTimeout?: number;

  get spinOnClick(): boolean {
    return this.getAttribute('spin-on-click') !== 'false';
  }

  /**
   * Time after which to show action message, in milliseconds.
   */
  get longWaitDurationMs(): number {
    return Number(this.getAttribute('long-wait-duration-ms')) || DEFAULT_LONG_WAIT_DURATION_MS;
  }

  connectedCallback() {
    this.elements = {
      button: this.querySelector('a,button:not([type]),[type="submit"],[type="button"]')!,
      actionMessage: this.querySelector('.spinner-button__action-message')!,
    };

    if (this.spinOnClick) {
      this.elements.button.addEventListener('click', () => this.toggleSpinner(true));
    }
    this.addEventListener('spinner.start', () => this.toggleSpinner(true));
    this.addEventListener('spinner.stop', () => this.toggleSpinner(false));
  }

  toggleSpinner(isVisible: boolean) {
    const { button, actionMessage } = this.elements;
    this.classList.toggle('spinner-button--spinner-active', isVisible);

    // Avoid setting disabled immediately to allow click event to propagate for form submission.
    setTimeout(() => {
      if (isVisible) {
        button.setAttribute('disabled', '');
      } else {
        button.removeAttribute('disabled');
      }
    }, 0);

    if (actionMessage) {
      actionMessage.textContent = isVisible ? (actionMessage.dataset.message as string) : '';
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
    this.elements.actionMessage?.classList.remove('usa-sr-only');
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
