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

  get showUnsupportedPasskey(): boolean {
    return this.hasAttribute('show-unsupported-passkey');
  }

  isSupported(): boolean {
    return !this.isPlatform || !this.isOnlyPasskeySupported || isWebauthnPasskeySupported();
  }

  toggleVisibleIfSupported() {
    if (this.isSupported()) {
      this.hidden = false;
    } else if (this.showUnsupportedPasskey) {
      this.hidden = false;
      this.classList.add('webauthn-input--unsupported-passkey');
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
