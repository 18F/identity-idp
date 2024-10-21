import isWebauthnPlatformAuthenticatorAvailable from './is-webauthn-platform-authenticator-available';

export class WebauthnInputElement extends HTMLElement {
  connectedCallback() {
    this.toggleVisibleIfPasskeySupported();
  }

  async toggleVisibleIfPasskeySupported() {
    if (await isWebauthnPlatformAuthenticatorAvailable()) {
      // if user is in the A/B test bucket, show. else, do not show
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
