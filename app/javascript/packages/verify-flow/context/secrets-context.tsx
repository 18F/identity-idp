import { createContext, useEffect, useCallback, useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import SecretSessionStorage from '@18f/identity-secret-session-storage';
import { useIfStillMounted } from '@18f/identity-react-hooks';

export type SecretValues = {
  example: string;
};

type SetItem = typeof SecretSessionStorage.prototype.setItem;

interface SecretsContextProviderProps {
  storeKey: Uint8Array;

  storeIV: Uint8Array;

  children?: ReactNode;
}

const STORAGE_KEY = 'verify';

const SecretsContext = createContext({
  storage: new SecretSessionStorage<SecretValues>(STORAGE_KEY),
  setItem: (() => {}) as SetItem,
});

function SecretsContextProvider({ storeKey, storeIV, children }: SecretsContextProviderProps) {
  const ifStillMounted = useIfStillMounted();
  const storage = useMemo(() => new SecretSessionStorage<SecretValues>(STORAGE_KEY), []);
  const [value, setValue] = useState({ storage, setItem: storage.setItem });
  const onChange = useCallback(() => {
    setValue({
      storage,
      setItem(...args) {
        storage.setItem(...args);
        onChange();
      },
    });
  }, []);

  useEffect(() => {
    crypto.subtle
      .importKey('raw', storeKey, 'AES-GCM', true, ['encrypt', 'decrypt'])
      .then((cryptoKey) => {
        storage.key = cryptoKey;
        storage.iv = storeIV;
        storage.load().then(ifStillMounted(onChange));
      });
  }, []);

  return <SecretsContext.Provider value={value}>{children}</SecretsContext.Provider>;
}

export { SecretsContextProvider };
export default SecretsContext;
