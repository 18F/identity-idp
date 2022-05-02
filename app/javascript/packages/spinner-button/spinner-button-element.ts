interface SpinnerButtonElements {
  button: HTMLButtonElement | HTMLInputElement | HTMLLinkElement;

  actionMessage: HTMLElement;
}

<<<<<<< HEAD
/**
 * Default time after which to show action message, in milliseconds.
 */
const DEFAULT_LONG_WAIT_DURATION_MS = 15000;
=======
interface SpinnerButtonOptions {
  longWaitDurationMs: number;
}

const DEFAULT_OPTIONS: SpinnerButtonOptions = {
  longWaitDurationMs: 15000,
};
>>>>>>> 84f0706fb (Refactor SpinnerButton as ViewComponent, custom element (#6243))

export class SpinnerButtonElement extends HTMLElement {
  elements: SpinnerButtonElements;

<<<<<<< HEAD
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
=======
  options: SpinnerButtonOptions;

  longWaitTimeout?: number;
>>>>>>> 84f0706fb (Refactor SpinnerButton as ViewComponent, custom element (#6243))

  connectedCallback() {
    this.elements = {
      button: this.querySelector('a,button:not([type]),[type="submit"],[type="button"]')!,
      actionMessage: this.querySelector('.spinner-button__action-message')!,
    };

<<<<<<< HEAD
    if (this.spinOnClick) {
      this.elements.button.addEventListener('click', () => this.toggleSpinner(true));
    }
=======
    this.options = {
      ...DEFAULT_OPTIONS,
      ...this.dataset,
    };

    this.options.longWaitDurationMs = Number(this.options.longWaitDurationMs);

    this.elements.button.addEventListener('click', () => this.toggleSpinner(true));
>>>>>>> 84f0706fb (Refactor SpinnerButton as ViewComponent, custom element (#6243))
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

<<<<<<< HEAD
    window.clearTimeout(this.#longWaitTimeout);
    if (isVisible) {
      this.#longWaitTimeout = window.setTimeout(
        () => this.handleLongWait(),
        this.longWaitDurationMs,
=======
    window.clearTimeout(this.longWaitTimeout);
    if (isVisible) {
      this.longWaitTimeout = window.setTimeout(
        () => this.handleLongWait(),
        this.options.longWaitDurationMs,
>>>>>>> 84f0706fb (Refactor SpinnerButton as ViewComponent, custom element (#6243))
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
<<<<<<< HEAD

export default SpinnerButtonElement;
=======
>>>>>>> 84f0706fb (Refactor SpinnerButton as ViewComponent, custom element (#6243))
