import { createContext, useContext, useEffect, useCallback, useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import SecretSessionStorage from '@18f/identity-secret-session-storage';
import { useIfStillMounted } from '@18f/identity-react-hooks';
import { VerifyFlowValues } from '../verify-flow';

type SecretValues = Partial<VerifyFlowValues>;

type SetItem = typeof SecretSessionStorage.prototype.setItem;

interface SecretsContextProviderProps {
  /**
   * Encryption key.
   */
  storeKey: Uint8Array;

  /**
   * Context provider children.
   */
  children?: ReactNode;
}

/**
 * Web storage key.
 */
const STORAGE_KEY = 'verify';

const SecretsContext = createContext({
  storage: new SecretSessionStorage<SecretValues>(STORAGE_KEY),
  setItem: (async () => {}) as SetItem,
});

export function SecretsContextProvider({ storeKey, children }: SecretsContextProviderProps) {
  const ifStillMounted = useIfStillMounted();
  const storage = useMemo(() => new SecretSessionStorage<SecretValues>(STORAGE_KEY), []);
  const [value, setValue] = useState({ storage, setItem: storage.setItem });
  const onChange = useCallback(() => {
    setValue({
      storage,
      async setItem(...args) {
        await storage.setItem(...args);
        onChange();
      },
    });
  }, []);

  useEffect(() => {
    crypto.subtle
      .importKey('raw', storeKey, 'AES-GCM', true, ['encrypt', 'decrypt'])
      .then((cryptoKey) => {
        storage.key = cryptoKey;
        storage.load().then(ifStillMounted(onChange));
      });
  }, []);

  return <SecretsContext.Provider value={value}>{children}</SecretsContext.Provider>;
}

export function useSecretValue<K extends keyof SecretValues>(
  key: K,
): [SecretValues[K], (nextValue: SecretValues[K]) => void] {
  const { storage, setItem } = useContext(SecretsContext);

  const setValue = (nextValue: SecretValues[K]) => setItem(key, nextValue);

  return [storage.getItem(key), setValue];
}

export default SecretsContext;
