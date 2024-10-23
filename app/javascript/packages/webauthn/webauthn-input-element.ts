import isWebauthnPlatformAuthenticatorAvailable from './is-webauthn-platform-authenticator-available';
import isWebauthnPasskeySupported from './is-webauthn-passkey-supported';

export class WebauthnInputElement extends HTMLElement {
  connectedCallback() {
    this.toggleVisibleIfPasskeySupported();
  }

  async toggleVisibleIfPasskeySupported() {
    if (isWebauthnPasskeySupported() && await isWebauthnPlatformAuthenticatorAvailable()) {
      this.hidden = false;
    } else {
      this.hidden = true;
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
