import isWebauthnPlatformAuthenticatorAvailable from './is-webauthn-platform-authenticator-available';

export class WebauthnInputElement extends HTMLElement {
  connectedCallback() {
    this.toggleVisibleIfPasskeySupported();
  }

  get isPlatform(): boolean {
    return this.hasAttribute('platform');
  }

  get showUnsupportedPasskey(): boolean {
    return this.hasAttribute('show-unsupported-passkey');
  }

  async toggleVisibleIfPasskeySupported() {
    if (!this.hasAttribute('hidden')) {
      return;
    }

    if (await isWebauthnPlatformAuthenticatorAvailable()) {
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
