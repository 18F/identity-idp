import { trackError } from '@18f/identity-analytics';

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
    this.recaptchaClient!.ready(async () => {
      const { recaptchaSiteKey: siteKey, recaptchaAction: action } = this;

      let token;
      try {
        token = await this.recaptchaClient!.execute(siteKey!, { action });
      } catch (error) {
        trackError(error);
      }

      this.tokenInput.value = token;
      this.submit();
    });
  }

  shouldInvokeChallenge(): boolean {
    return !!(this.recaptchaSiteKey && this.recaptchaClient);
  }

  handleFormSubmit = (event: SubmitEvent) => {
    if (this.shouldInvokeChallenge()) {
      event.preventDefault();
      this.invokeChallenge();
    }
  };
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
