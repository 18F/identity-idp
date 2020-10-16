const encode = function (text) {
  const enc = new TextEncoder();
  return enc.encode(text);
  // btoa(text);
};

class AesCipher {
  constructor() {
    this.key = window.crypto.subtle.generateKey(
      {
        name: 'AES-GCM',
        length: 256,
      },
      true,
      ['encrypt', 'decrypt'],
    );
  }

  encrypt(plaintext) {
    const iv = window.crypto.getRandomValues(new Uint8Array(32));
    return window.crypto.subtle.encrypt(
      {
        name: 'AES-GCM',
        // eslint-disable-next-line object-shorthand
        iv: iv,
      },
      this.key,
      encode(plaintext),
    );
  }

  key() {
    return this.key;
  }
}

export default AesCipher;
