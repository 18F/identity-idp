import { trackEvent } from '@18f/identity-analytics';

class PasswordConfirmationElement extends HTMLElement {
  connectedCallback() {
    console.log("hello...");
    this.toggle.addEventListener('change', () => this.setInputType());
    this.toggle.addEventListener('click', () => this.trackToggleEvent());
    this.input_confirmation.addEventListener('input', () => this.validatePassword());
    this.setInputType();
  }

  /**
   * Checkbox toggle for visibility.
   */
  get toggle(): HTMLInputElement {
    return this.querySelector('.password-toggle__toggle')!;
  }

  /**
   * Text or password input.
   */
  get input(): HTMLInputElement {
    return this.querySelector('.password-confirmation__input1')!;
  }

  get input_confirmation(): HTMLInputElement {
    return this.querySelector('.password-confirmation__input2')!;
  }
  setInputType() {
    const checked = this.toggle.checked ? 'text' : 'password';
    this.input.type = checked;
    this.input_confirmation.type = checked;
  }

  trackToggleEvent() {
    trackEvent('Show Password button clicked', { path: window.location.pathname });
  }

  validatePassword() {
    console.log("validatePassword");
    const password = this.input.value;
    const confirmation = this.input_confirmation.value;

    if (password && password !== confirmation) {
      // TODO: Change message
      console.log("passwords do not match");
      this.input_confirmation.setCustomValidity('passwords do not match!');      
    } else {
      this.input_confirmation.setCustomValidity('');
    }
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-password-confirmation': PasswordConfirmationElement;
  }
}

if (!customElements.get('lg-password-confirmation')) {
  customElements.define('lg-password-confirmation', PasswordConfirmationElement);
}

export default PasswordConfirmationElement;
