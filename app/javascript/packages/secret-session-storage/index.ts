type JSONValue = string | number | boolean | null | JSONValue[] | { [key: string]: JSONValue };

/**
 * Convert an ArrayBuffer to an equivalent string.
 */
export const ab2s = (buffer: Uint8Array) => String.fromCharCode.apply(null, new Uint8Array(buffer));

/**
 * Convert a string to an equivalent ArrayBuffer.
 */
export const s2ab = (string: string) => Uint8Array.from(string, (c) => c.charCodeAt(0));

class SecretSessionStorage<S extends Record<string, JSONValue>> {
  storageKey: string;

  storage: S = {} as S;

  key: CryptoKey;

  iv: Uint8Array;

  constructor(storageKey: string) {
    this.storageKey = storageKey;
  }

  async load() {
    const storage = await this.#readStorage();
    if (storage) {
      this.storage = storage;
    }
  }

  setItem(key: keyof S, value: S[typeof key]) {
    this.storage[key] = value;
    this.#writeStorage();
  }

  getItem(key: keyof S) {
    return this.storage[key];
  }

  async #readStorage() {
    try {
      const rawData = sessionStorage.getItem(this.storageKey)!;

      const data = await crypto.subtle.decrypt(
        { name: 'AES-GCM', iv: this.iv },
        this.key,
        encode(rawData),
      );

      return JSON.parse(ab2s(data));
    } catch {}
  }

  async #writeStorage() {
    const data = await crypto.subtle.encrypt(
      { name: 'AES-GCM', iv: this.iv },
      this.key,
      s2ab(JSON.stringify(this.storage)),
    );

    sessionStorage.setItem(this.storageKey, ab2s(data));
  }
}

export default SecretSessionStorage;
