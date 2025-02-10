import { t } from '@18f/identity-i18n';

class PasswordConfirmationElement extends HTMLElement {
  connectedCallback() {
    this.toggle.addEventListener('change', () => this.setInputType());
    this.input.addEventListener('input', () => this.validatePassword());
    this.inputConfirmation.addEventListener('input', () => this.validatePassword());
    this.setInputType();
  }

  /**
   * Checkbox toggle for visibility.
   */
  get toggle(): HTMLInputElement {
    return this.querySelector('.password-confirmation__toggle')! as HTMLInputElement;
  }

  /**
   * Password input.
   */
  get input(): HTMLInputElement {
    return this.querySelector('.password-confirmation__input')! as HTMLInputElement;
  }

  /**
   * Password confirmation input.
   */
  get inputConfirmation(): HTMLInputElement {
    return this.querySelector('.password-confirmation__input-confirmation')! as HTMLInputElement;
  }

  setInputType() {
    const checked = this.toggle.checked ? 'text' : 'password';
    this.input.type = checked;
    this.inputConfirmation.type = checked;
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
