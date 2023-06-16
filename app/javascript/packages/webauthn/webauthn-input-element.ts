import isWebauthnPlatformSupported from './is-webauthn-platform-supported';
import isWebauthnSupported from './is-webauthn-supported';

export class WebauthnInputElement extends HTMLElement {
  connectedCallback() {
    this.toggleVisibleIfSupported();
  }

  get isPlatform(): boolean {
    return this.hasAttribute('platform');
  }

  async toggleVisibleIfSupported() {
    if (isWebauthnSupported() && (!this.isPlatform || (await isWebauthnPlatformSupported()))) {
      this.removeAttribute('hidden');
    }
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-webauthn-input': WebauthnInputElement;
  }
}

if (!customElements.get('lg-webauthn-input')) {
  customElements.define('lg-webauthn-input', WebauthnInputElement);
}

export default WebauthnInputElement;
