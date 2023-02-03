import type SpinnerButtonElement from '@18f/identity-spinner-button/spinner-button-element';

class CaptchaSubmitButtonElement extends HTMLElement {
  connectedCallback() {
    this.button.addEventListener('click', (event) => this.handleButtonClick(event));
  }

  get isExempt(): boolean {
    return !this.recaptchaSiteKey || this.hasAttribute('exempt');
  }

  get button(): HTMLButtonElement {
    return this.querySelector('button')!;
  }

  get tokenInput(): HTMLInputElement {
    return this.querySelector('[type=hidden]')!;
  }

  get spinnerButton(): SpinnerButtonElement {
    return this.querySelector('lg-spinner-button')!;
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

  handleButtonClick(event: MouseEvent) {
    event.preventDefault();

    if (this.form && !this.form.reportValidity()) {
      return;
    }

    if (this.isExempt) {
      this.submit();
    } else {
      this.invokeChallenge();
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
