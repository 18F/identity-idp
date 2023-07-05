import isWebauthnPasskeySupported from './is-webauthn-passkey-supported';
import isWebauthnPlatformSupported from './is-webauthn-platform-supported';
import isWebauthnSupported from './is-webauthn-supported';

export class WebauthnInputElement extends HTMLElement {
  isInitialized = false;

  async connectedCallback() {
    await this.toggleVisibleIfSupported();
    this.isInitialized = true;
  }

  get isPlatform(): boolean {
    return this.hasAttribute('platform');
  }

  get isOnlyPasskeySupported(): boolean {
    return this.hasAttribute('passkey-supported-only');
  }

  async isSupported(): Promise<boolean> {
    if (!isWebauthnSupported()) {
      return false;
    }

    if (!this.isPlatform) {
      return true;
    }

    if (!(await isWebauthnPlatformSupported())) {
      return false;
    }

    return !this.isOnlyPasskeySupported || isWebauthnPasskeySupported();
  }

  async toggleVisibleIfSupported() {
    if (await this.isSupported()) {
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
