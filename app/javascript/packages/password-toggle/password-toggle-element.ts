import { trackEvent } from '@18f/identity-analytics';
import { tooltip } from 'identity-style-guide';

interface PasswordToggleLabels {
  shown: string;
  hidden: string;
}

class PasswordToggleElement extends HTMLElement {
  #isVisible: boolean = false;

  connectedCallback() {
    tooltip.on(this);
    this.toggle.addEventListener('click', () => this.onToggleClick());
    this.setInputType();
  }

  get labels(): PasswordToggleLabels {
    return {
      shown: this.getAttribute('toggle-label-shown')!,
      hidden: this.getAttribute('toggle-label-hidden')!,
    };
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

  announce() {
    this.announcer.textContent = this.isVisible ? this.labels.shown : this.labels.hidden;
  }

  onToggleClick() {
    this.isVisible = !this.isVisible;
    this.setInputType();
    this.announce();
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
