import { trackEvent } from '@18f/identity-analytics';

interface PasswordToggleLabels {
  show: string;
  hide: string;
}

class PasswordToggleElement extends HTMLElement {
  connectedCallback() {
    this.toggle.addEventListener('click', () => this.onToggleClick());
    this.setInputType();
  }

  get labels(): PasswordToggleLabels {
    return {
      show: this.getAttribute('toggle-label-show')!,
      hide: this.getAttribute('toggle-label-hide')!,
    };
  }

  get input(): HTMLInputElement {
    return this.querySelector('.password-toggle__input')!;
  }

  get toggle(): HTMLButtonElement {
    return this.querySelector('.password-toggle__toggle')!;
  }

  setInputType() {
    const isCurrentlyHidden = this.toggle.textContent === this.labels.show;
    this.input.type = isCurrentlyHidden ? 'text' : 'password';
    this.toggle.textContent = isCurrentlyHidden ? this.labels.hide : this.labels.show;
  }

  onToggleClick() {
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
