/**
 * Serializable JSON value.
 */
type JSONValue = string | number | boolean | null | JSONValue[] | { [key: string]: JSONValue };

/**
 * Convert an ArrayBuffer to an equivalent string.
 */
export const ab2s = (buffer: ArrayBuffer) =>
  String.fromCharCode.apply(null, new Uint8Array(buffer));

/**
 * Convert a string to an equivalent ArrayBuffer.
 */
export const s2ab = (string: string) => Uint8Array.from(string, (c) => c.charCodeAt(0));

class SecretSessionStorage<S extends Record<string, JSONValue>> {
  /**
   * Web storage key.
   */
  storageKey: string;

  /**
   * In-memory reflection of unencrypted web storage payload.
   */
  storage: S = {} as S;

  /**
   * Encryption key.
   */
  key: CryptoKey;

  /**
   * Constructs a new session store.
   *
   * @param storageKey Web storage key.
   * @param key Encryption key.
   */
  constructor(storageKey: string) {
    this.storageKey = storageKey;
  }

  /**
   * Reads and decrypts storage object into in-memory reflection, if available.
   */
  async load() {
    const storage = await this.#readStorage();
    if (storage) {
      this.storage = storage;
    }
  }

  /**
   * Sets a value into storage.
   *
   * @param key Storage object key.
   * @param value Storage object value.
   */
  async setItem(key: keyof S, value: S[typeof key]) {
    this.storage[key] = value;
    await this.#writeStorage();
  }

  /**
   * Sets a patch of values into storage.
   *
   * @param values Storage object values.
   */
  async setItems(values: Partial<S>) {
    Object.assign(this.storage, values);
    await this.#writeStorage();
  }

  /**
   * Gets a value from the in-memory storage.
   *
   * @param key Storage object key.
   */
  getItem(key: keyof S) {
    return this.storage[key];
  }

  /**
   * Returns values from in-memory storage.
   */
  getItems() {
    return this.storage;
  }

  /**
   * Remove all values from in-memory and persisted storage.
   */
  clear() {
    sessionStorage.removeItem(this.storageKey);
    this.storage = {} as S;
  }

  /**
   * Reads and decrypts storage object, if available.
   */
  async #readStorage() {
    try {
      const storageData = sessionStorage.getItem(this.storageKey)!;
      const [encryptedData, iv] = (JSON.parse(storageData) as [string, string]).map(s2ab);
      const data = await window.crypto.subtle.decrypt(
        { name: 'AES-GCM', iv },
        this.key,
        encryptedData,
      );

      return JSON.parse(ab2s(data));
    } catch {}
  }

  /**
   * Encrypts and writes current in-memory reflection of storage object to web storage.
   */
  async #writeStorage() {
    const iv = window.crypto.getRandomValues(new Uint8Array(12));
    const encryptedData = await window.crypto.subtle.encrypt(
      { name: 'AES-GCM', iv },
      this.key,
      s2ab(JSON.stringify(this.storage)),
    );

    sessionStorage.setItem(this.storageKey, JSON.stringify([encryptedData, iv].map(ab2s)));
  }
}

export default SecretSessionStorage;
