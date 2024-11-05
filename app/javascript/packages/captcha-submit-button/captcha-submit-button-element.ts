import { trackError } from '@18f/identity-analytics';

/**
 * Maximum time (in milliseconds) to wait on reCAPTCHA to finish loading once a form is submitted
 * before considering reCAPTCHA as having failed to load.
 */
export const FAILED_LOAD_DELAY_MS = 5_000;

class CaptchaSubmitButtonElement extends HTMLElement {
  form: HTMLFormElement | null;

  connectedCallback() {
    this.form = this.closest('form');

    this.form?.addEventListener('submit', this.handleFormSubmit);
  }

  disconnectedCallback() {
    this.form?.removeEventListener('submit', this.handleFormSubmit);
  }

  get button(): HTMLButtonElement {
    return this.querySelector('button')!;
  }

  get tokenInput(): HTMLInputElement {
    return this.querySelector('[type=hidden]')!;
  }

  get recaptchaSiteKey(): string | null {
    return this.getAttribute('recaptcha-site-key');
  }

  get recaptchaAction(): string {
    return this.getAttribute('recaptcha-action')!;
  }

  get isRecaptchaEnterprise(): boolean {
    return this.getAttribute('recaptcha-enterprise') === 'true';
  }

  get recaptchaClient(): ReCaptchaV2.ReCaptcha | undefined {
    if (this.isRecaptchaEnterprise) {
      return globalThis.grecaptcha?.enterprise;
    }

    return globalThis.grecaptcha;
  }

  submit() {
    this.form?.submit();
  }

  invokeChallenge() {
    this.#onReady(async () => {
      const { recaptchaSiteKey: siteKey, recaptchaAction: action } = this;

      let token;
      try {
        token = await this.recaptchaClient!.execute(siteKey!, { action });
      } catch (error) {
        trackError(error, { errorId: 'recaptchaExecute' });
      }

      this.tokenInput.value = token;
      this.submit();
    });
  }

  shouldInvokeChallenge(): boolean {
    return !!this.recaptchaSiteKey;
  }

  handleFormSubmit = (event: SubmitEvent) => {
    if (this.shouldInvokeChallenge()) {
      event.preventDefault();
      this.invokeChallenge();
    }
  };

  #onReady(callback: Parameters<ReCaptchaV2.ReCaptcha['ready']>[0]) {
    if (this.recaptchaClient) {
      this.recaptchaClient.ready(callback);
    } else {
      // If reCAPTCHA hasn't finished loading by the time the form is submitted, we can enqueue the
      // callback to be invoked once loaded by appending a callback to the ___grecaptcha_cfg global.
      //
      // See: https://developers.google.com/recaptcha/docs/loading

      const failedLoadTimeoutId = setTimeout(() => this.submit(), FAILED_LOAD_DELAY_MS);
      const clearFailedLoadTimeout = () => clearTimeout(failedLoadTimeoutId);

      /* eslint-disable no-underscore-dangle */
      globalThis.___grecaptcha_cfg ??= { fns: [] };
      globalThis.___grecaptcha_cfg.fns.push(clearFailedLoadTimeout, callback);
      /* eslint-enable no-underscore-dangle */
    }
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-captcha-submit-button': CaptchaSubmitButtonElement;
  }
}

if (!customElements.get('lg-captcha-submit-button')) {
  customElements.define('lg-captcha-submit-button', CaptchaSubmitButtonElement);
}

export default CaptchaSubmitButtonElement;
