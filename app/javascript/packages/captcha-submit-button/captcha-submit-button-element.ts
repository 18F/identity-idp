import type SpinnerButtonElement from '@18f/identity-spinner-button/spinner-button-element';

class CaptchaSubmitButtonElement extends HTMLElement {
  connectedCallback() {
    this.button.addEventListener('click', (event) => this.handleButtonClick(event));
  }

  get exempt(): boolean {
    return this.hasAttribute('exempt');
  }

  get button(): HTMLButtonElement {
    return this.querySelector('button')!;
  }

  get spinnerButton(): SpinnerButtonElement {
    return this.querySelector('lg-spinner-button')!;
  }

  get form(): HTMLFormElement | null {
    return this.closest('form');
  }

  get recaptchaSiteKey(): string {
    return this.getAttribute('recaptcha-site-key')!;
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
      const token = await grecaptcha.execute(siteKey, { action });
      const input = document.createElement('input');
      input.name = 'recaptcha_token';
      input.type = 'hidden';
      input.value = token;
      this.appendChild(input);
      this.submit();
    });
  }

  handleButtonClick(event: MouseEvent) {
    event.preventDefault();

    if (this.form && !this.form.reportValidity()) {
      return;
    }

    if (this.exempt) {
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
