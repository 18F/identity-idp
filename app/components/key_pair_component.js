import { trackEvent } from '@18f/identity-analytics';

class KeyPairGenerator extends HTMLElement {
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

    const encodedPrivate = await crypto.subtle.exportKey('pkcs8', keypair.privateKey);
    this.privateB64key = btoa(String.fromCharCode.apply(null, new Uint8Array(encodedPrivate)));

    const encodedPublic = await crypto.subtle.exportKey('spki', keypair.publicKey);
    this.publicB64key = btoa(String.fromCharCode.apply(null, new Uint8Array(encodedPublic)));
    const t1 = performance.now();
    this.duration = t1 - t0; // milliseconds
  }

  constructor() {
    super();
  }

  connectedCallback() {
    this.generateKeyPair().then(() => {
      trackEvent('IdV: key pair generation', {
        duration: this.duration.toFixed(0),
      });
    });
  }
}

customElements.define('lg-kp', KeyPairGenerator);
