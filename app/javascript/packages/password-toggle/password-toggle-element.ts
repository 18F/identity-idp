import { trackEvent } from '@18f/identity-analytics';
import { tooltip } from 'identity-style-guide';

interface PasswordToggleLabels {}

class PasswordToggleElement extends HTMLElement {
  #isVisible: boolean = false;

  connectedCallback() {
    tooltip.on(this);
    this.toggle.addEventListener('click', () => this.onToggleClick());
    this.setInputType();
  }

  get labels(): PasswordToggleLabels {
    return {};
  }

  get input(): HTMLInputElement {
    return this.querySelector('.password-toggle__input')!;
  }

  get toggle(): HTMLButtonElement {
    return this.querySelector('.password-toggle__toggle')!;
  }

  get announcer(): HTMLElement {
    return this.querySelector('.password-toggle__announcer')!;
  }

  get icon(): SVGUseElement {
    return this.querySelector('.usa-icon use')!;
  }

  get isVisible(): boolean {
    return this.#isVisible;
  }

  set isVisible(nextIsVisible: boolean) {
    this.#isVisible = nextIsVisible;
    this.setInputType();
  }

  setInputType() {
    this.input.type = this.isVisible ? 'text' : 'password';
    this.toggle.setAttribute('aria-checked', this.isVisible ? 'true' : 'false');
  }

  onToggleClick() {
    this.isVisible = !this.isVisible;
    this.setInputType();
    trackEvent('Show Password button clicked', { path: window.location.pathname });
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
