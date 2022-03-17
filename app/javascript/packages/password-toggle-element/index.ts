import { once } from '@18f/identity-decorators';

interface PasswordToggleStrings {
  /**
   * Visible state text when password is visible.
   */
  visible: string;

  /**
   * Visible state text when password is hidden.
   */
  hidden: string;
}

interface PasswordToggleElements {
  /**
   * Checkbox toggle for visibility.
   */
  toggle: HTMLInputElement;

  /**
   * Text or password input.
   */
  input: HTMLInputElement;

  /**
   * Visible state live region for assistive technology announcements.
   */
  visibleState: HTMLElement;
}

export class PasswordToggleElement extends HTMLElement {
  connectedCallback() {
    this.elements.toggle.addEventListener('change', () => this.onToggle());
    this.setInputType();
  }

  @once()
  get strings(): PasswordToggleStrings {
    return JSON.parse(this.querySelector('.password-toggle__strings')!.textContent!);
  }

  @once()
  get elements(): PasswordToggleElements {
    return {
      toggle: this.querySelector('.password-toggle__toggle')!,
      input: this.querySelector('.password-toggle__input')!,
      visibleState: this.querySelector('.password-toggle__visible-state')!,
    };
  }

  onToggle() {
    this.setInputType();
    this.setVisibleStateLiveRegionText();
  }

  setInputType() {
    this.elements.input.type = this.elements.toggle.checked ? 'text' : 'password';
  }

  setVisibleStateLiveRegionText() {
    this.elements.visibleState.textContent = this.elements.toggle.checked
      ? this.strings.visible
      : this.strings.hidden;
  }
}
