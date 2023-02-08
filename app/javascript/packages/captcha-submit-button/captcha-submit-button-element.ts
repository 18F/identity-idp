export const CAPTCHA_EVENT_NAME = 'captcha-challenge';

class CaptchaSubmitButtonElement extends HTMLElement {
  connectedCallback() {
    this.button.addEventListener('click', (event) => this.handleButtonClick(event));
  }

  get button(): HTMLButtonElement {
    return this.querySelector('button')!;
  }

  get tokenInput(): HTMLInputElement {
    return this.querySelector('[type=hidden]')!;
  }

  get form(): HTMLFormElement | null {
    return this.closest('form');
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

  handleButtonClick(event: MouseEvent) {
    event.preventDefault();

    if (this.form && !this.form.reportValidity()) {
      // Prevent any associated custom click handling, e.g. spinner button spinning
      event.stopImmediatePropagation();
      return;
    }

    if (this.shouldInvokeChallenge()) {
      this.invokeChallenge();
    } else {
      this.submit();
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
