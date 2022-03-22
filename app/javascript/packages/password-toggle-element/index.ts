import { once } from '@18f/identity-decorators';

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

export class PasswordToggleElement extends HTMLElement {
  connectedCallback() {
    this.elements.toggle.addEventListener('change', () => this.setInputType());
    this.setInputType();
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
}
