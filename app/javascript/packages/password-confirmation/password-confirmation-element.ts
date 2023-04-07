import { trackEvent } from '@18f/identity-analytics';
import { t } from '@18f/identity-i18n';

class PasswordConfirmationElement extends HTMLElement {
  connectedCallback() {
    this.toggle.addEventListener('change', () => this.setInputType());
    this.toggle.addEventListener('click', () => this.trackToggleEvent());
    this.input_confirmation.addEventListener('change', () => this.validatePassword());
    this.setInputType();
  }

  /**
   * Checkbox toggle for visibility.
   */
  get toggle(): HTMLInputElement {
    return this.querySelector('.password-toggle__toggle')! as HTMLInputElement;
  }

  /**
   * Text or password input.
   */
  get input(): HTMLInputElement {
    return this.querySelector('.password-confirmation__input1')! as HTMLInputElement;
  }

  /**
   * Text or password confirmation input.
   */
  get input_confirmation(): HTMLInputElement {
    return this.querySelector('.password-confirmation__input2')! as HTMLInputElement;
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
    const password = this.input.value;
    const confirmation = this.input_confirmation.value;

    if (password && password !== confirmation) {
      const errorMsg = t('components.password_confirmation.errors.mismatch');
      this.input_confirmation.setCustomValidity(errorMsg);
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
