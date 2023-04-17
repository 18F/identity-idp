import { trackEvent } from '@18f/identity-analytics';
import { t } from '@18f/identity-i18n';

class PasswordConfirmationElement extends HTMLElement {
  connectedCallback() {
    this.toggle.addEventListener('change', () => this.setInputType());
    this.toggle.addEventListener('click', () => this.trackToggleEvent());
    this.inputConfirmation.addEventListener('change', () => this.validatePassword());
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
    return this.querySelector('.password-confirmation__input')! as HTMLInputElement;
  }

  /**
   * Text or password confirmation input.
   */
  get inputConfirmation(): HTMLInputElement {
    return this.querySelector('.password-confirmation__input-confirmation')! as HTMLInputElement;
  }

  setInputType() {
    const checked = this.toggle.checked ? 'text' : 'password';
    this.input.type = checked;
    this.inputConfirmation.type = checked;
  }

  trackToggleEvent() {
    trackEvent('Show Password button clicked', { path: window.location.pathname });
  }

  validatePassword() {
    const password = this.input.value;
    const confirmation = this.inputConfirmation.value;

    if (password && password !== confirmation) {
      const errorMsg = t('components.password_confirmation.errors.mismatch');
      this.inputConfirmation.setCustomValidity(errorMsg);
    } else {
      this.inputConfirmation.setCustomValidity('');
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
