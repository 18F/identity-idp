import { trackEvent } from '@18f/identity-analytics';

class KeyPairGeneratorElement extends HTMLElement {
  connectedCallback() {
    this.generateKeyPair().then(() => {
      if (this.duration === undefined) {
        this.duration = -1;
      }
      trackEvent('IdV: key pair generation', {
        duration: this.duration.toFixed(0),
        location: this.dataset.location,
      });
    });
  }

  async generateKeyPair() {
    const t0 = performance.now();

    const keypair = await crypto.subtle.generateKey(
      {
        name: 'RSA-OAEP',
        modulusLength: 4096,
        publicExponent: new Uint8Array([0x01, 0x00, 0x01]),
        hash: 'SHA-256',
      },
      true,
      ['encrypt', 'decrypt'],
    );
    this.privateB64key = await this.exportKey('pkcs8', keypair.privateKey);
    this.publicB64key = await this.exportKey('spki', keypair.publicKey);

    const t1 = performance.now();
    this.duration = t1 - t0; // milliseconds
  }

  async exportKey(format, key) {
    const encodedKey = await crypto.subtle.exportKey(format, key);
    return btoa(String.fromCharCode.apply(null, new Uint8Array(encodedKey)));
  }
}

customElements.define('lg-key-pair-generator', KeyPairGeneratorElement);
