import isWebauthnPasskeySupported from './is-webauthn-passkey-supported';

export class WebauthnInputElement extends HTMLElement {
  connectedCallback() {
    this.toggleVisibleIfSupported();
  }

  get isPlatform(): boolean {
    return this.hasAttribute('platform');
  }

  get isOnlyPasskeySupported(): boolean {
    return this.hasAttribute('passkey-supported-only');
  }

  isSupported(): boolean {
    return !this.isPlatform || !this.isOnlyPasskeySupported || isWebauthnPasskeySupported();
  }

  toggleVisibleIfSupported() {
    if (this.isSupported()) {
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
