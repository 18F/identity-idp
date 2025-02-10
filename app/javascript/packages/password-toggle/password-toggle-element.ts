class PasswordToggleElement extends HTMLElement {
  connectedCallback() {
    this.toggle.addEventListener('change', () => this.setInputType());
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
    return this.querySelector('.password-toggle__input')!;
  }

  setInputType() {
    this.input.type = this.toggle.checked ? 'text' : 'password';
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
