import isWebauthnPlatformAuthenticatorAvailable from './is-webauthn-platform-authenticator-available';
import isWebauthnPasskeySupported from './is-webauthn-passkey-supported';
import { trackEvent } from '@18f/identity-analytics';

export class WebauthnInputElement extends HTMLElement {
  connectedCallback() {
    this.toggleVisibleIfPasskeySupported();
  }

  get isOptedInToAbTest(): boolean {
    return this.hasAttribute('desktop-ft-unlock-option');
  }

  get isPlatform(): boolean {
    return this.hasAttribute('platform');
  }

  get showUnsupportedPasskey(): boolean {
    return this.hasAttribute('show-unsupported-passkey');
  }

  async toggleVisibleIfPasskeySupported() {
    const webauthnPlatformAvailable = await isWebauthnPlatformAuthenticatorAvailable();

    if (!this.hasAttribute('hidden')) {
      return;
    }

    if ((isWebauthnPasskeySupported() || this.isOptedInToAbTest) && webauthnPlatformAvailable) {
      this.hidden = false;
    } else if (this.showUnsupportedPasskey) {
      this.hidden = false;
      this.classList.add('webauthn-input--unsupported-passkey');
    }

    if(this.isOptedInToAbTest && !webauthnPlatformAvailable) {
      trackEvent('desktop_ab_test_option_shown')
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
