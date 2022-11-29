import { trackEvent } from '@18f/identity-analytics';
import { tooltip } from 'identity-style-guide';

interface PasswordToggleLabels {
  show: string;
  hide: string;
}

function replaceHashFragment(url: string, nextHashFragment: string): string {
  const parsedURL = new URL(url);
  parsedURL.hash = nextHashFragment;
  return parsedURL.toString();
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

  get tooltip(): HTMLElement {
    return this.querySelector('.usa-tooltip__body')!;
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
    this.tooltip.textContent = this.isVisible ? this.labels.hide : this.labels.show;
    this.icon.href.baseVal = replaceHashFragment(
      this.icon.href.baseVal,
      this.isVisible ? 'visibility_off' : 'visibility',
    );
  }

  onToggleClick() {
    this.setInputType();
    this.isVisible = !this.isVisible;
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
