import isWebauthnPlatformAuthenticatorAvailable from './is-webauthn-platform-authenticator-available';
import isWebauthnPasskeySupported from './is-webauthn-passkey-supported';

export class WebauthnInputElement extends HTMLElement {
  connectedCallback() {
    this.toggleVisibleIfPasskeySupported();
  }

  get isOptedInToAbTest(): boolean {
    return this.hasAttribute('desktop-ft-ab-test');
  }

  get isPlatform(): boolean {
    return this.hasAttribute('platform');
  }

  async toggleVisibleIfPasskeySupported() {
    if (
      (isWebauthnPasskeySupported() || this.isOptedInToAbTest) &&
      (await isWebauthnPlatformAuthenticatorAvailable())
    ) {
      this.hidden = false;
    } else {
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
