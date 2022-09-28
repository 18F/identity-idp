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

  customSplit(str, maxLength) {
    if (str.length <= maxLength) return str;
    var reg = new RegExp('.{1,' + maxLength + '}', 'g');
    var parts = str.match(reg);
    return parts.join('\n');
  }

  constructor() {
    super();
  }

  connectedCallback() {
    this.generateKeyPair()
      .then(() => {
        this.innerHTML = `
        <h2>Duration</h2>
        <div> The generation of the key pair took ${this.duration.toFixed(0)} milliseconds.</div>
        <h2>Public Key</h2>
        <div style='font-family: monospace; font-size: 8px'>${this.customSplit(
          this.publicB64key,
          65,
        )}</div>
      `;
      })
      .then(() => {
        trackEvent('IdV: key pair generation', {
          duration: this.duration.toFixed(0),
        });
      });
  }
}

customElements.define('lg-kp', KeyPairGenerator);
