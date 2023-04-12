export const CAPTCHA_EVENT_NAME = 'lg:captcha-submit-button:challenge';

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

  submit() {
    this.form?.submit();
  }

  invokeChallenge() {
    grecaptcha.ready(async () => {
      const { recaptchaSiteKey: siteKey, recaptchaAction: action } = this;
      const token = await grecaptcha.execute(siteKey!, { action });
      this.tokenInput.value = token;
      this.submit();
    });
  }

  shouldInvokeChallenge(): boolean {
    if (!this.recaptchaSiteKey) {
      return false;
    }

    const event = new CustomEvent(CAPTCHA_EVENT_NAME, { bubbles: true, cancelable: true });
    this.dispatchEvent(event);
    return !event.defaultPrevented;
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
