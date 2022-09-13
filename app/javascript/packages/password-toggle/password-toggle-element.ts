import { once } from '@18f/identity-decorators';
import { trackEvent } from '@18f/identity-analytics'

interface PasswordToggleElements {
  /**
   * Checkbox toggle for visibility.
   */
  toggle: HTMLInputElement;

  /**
   * Text or password input.
   */
  input: HTMLInputElement;
}

class PasswordToggleElement extends HTMLElement {
  connectedCallback() {
    this.elements.toggle.addEventListener('change', () => this.setInputType());
    this.setInputType();
    this.showPasswordButtonClick();
  }

  @once()
  get elements(): PasswordToggleElements {
    return {
      toggle: this.querySelector('.password-toggle__toggle')!,
      input: this.querySelector('.password-toggle__input')!,
    };
  }

  setInputType() {
    this.elements.input.type = this.elements.toggle.checked ? 'text' : 'password';
  }

  showPasswordButtonClick() {
    this.elements.toggle.addEventListener('click', () => {
      trackEvent('Button clicked', { path: window.location.pathname });
    });
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-password-toggle': PasswordToggleElement;
  }
}

if (!customElements.get('lg-password-toggle')) {
  customElements.define('lg-password-toggle', PasswordToggleElement);
}

export default PasswordToggleElement;
