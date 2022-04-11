type JSONValue = string | number | boolean | null | JSONValue[] | { [key: string]: JSONValue };

const ab2s = (buffer: Uint8Array) => String.fromCharCode.apply(null, new Uint8Array(buffer));

export const encode = (string: string) => Uint8Array.from(string, (c) => c.charCodeAt(0));

class SecretSessionStorage<S extends Record<string, JSONValue>> {
  storageKey: string;

  storage: S = {} as S;

  key: CryptoKey;

  iv: Uint8Array;

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
      encode(JSON.stringify(this.storage)),
    );

    sessionStorage.setItem(this.storageKey, ab2s(data));
  }
}

export default SecretSessionStorage;
