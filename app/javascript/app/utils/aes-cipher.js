// @ts-check

const encode = function (text) {
  const enc = new TextEncoder();
  return enc.encode(text);
  // btoa(text);
};

function ab2str(buf) {
  return String.fromCharCode.apply(null, new Uint16Array(buf));
}

function getTag(encrypted, tagLength = 128) {
  return encrypted.slice(encrypted.byteLength - ((tagLength + 7) >> 3));
}

class AesCipher {
  static async encrypt(plaintext) {
    const key = await window.crypto.subtle.generateKey(
      {
        name: 'AES-GCM',
        length: 256,
      },
      true,
      ['encrypt', 'decrypt'],
    );

    const iv = window.crypto.getRandomValues(new Uint8Array(32));

    const [ciphertext, rawKey] = await Promise.all([
      window.crypto.subtle.encrypt(
        {
          name: 'AES-GCM',
          iv,
        },
        key,
        encode(plaintext),
      ),
      window.crypto.subtle.exportKey('raw', key),
    ]);

    return {
      key: new Uint8Array(rawKey),
      iv: iv,
      ciphertext: new Uint8Array(ciphertext),
      tag: new Uint8Array(getTag(ciphertext)),
      plaintext,
    };
  }
}

export default AesCipher;
