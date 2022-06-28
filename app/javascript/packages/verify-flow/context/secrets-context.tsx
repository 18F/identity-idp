import { createContext, useContext, useEffect, useState } from 'react';
import type { ReactNode, Dispatch } from 'react';
import SecretSessionStorage from '@18f/identity-secret-session-storage';
import type { VerifyFlowValues } from '../verify-flow';

type SecretKeys = 'userBundleToken' | 'personalKey' | 'completionURL';

export type SecretValues = Pick<VerifyFlowValues, SecretKeys>;

type SetItems = typeof SecretSessionStorage.prototype.setItems;

interface SecretsContextProviderProps {
  /**
   * Secrets storage.
   */
  storage: SecretSessionStorage<SecretValues>;

  /**
   * Context provider children.
   */
  children?: ReactNode;
}

/**
 * Minimal set of flow values to be synced to secret session storage.
 */
const SYNCED_SECRET_VALUES: SecretKeys[] = ['userBundleToken', 'personalKey', 'completionURL'];

const SecretsContext = createContext({
  storage: new SecretSessionStorage<SecretValues>(''),
  setItems: (async () => {}) as SetItems,
});

SecretsContext.displayName = 'SecretsContext';

const pick = (obj: object, keys: string[]) =>
  Object.fromEntries(keys.map((key) => [key, obj[key]]));

const isStorageEqual = (values: object, nextValues: object) =>
  Object.keys(nextValues).every((key) => values[key] === nextValues[key]);

function useIdleCallbackEffect(callback: () => void, deps: any[]) {
  useEffect(() => {
    // Idle callback is implemented as a progressive enhancement in supported environments...
    if (typeof requestIdleCallback === 'function') {
      const callbackId = requestIdleCallback(callback);
      return () => cancelIdleCallback(callbackId);
    }

    // ...where the fallback behavior is to invoke the callback synchronously.
    callback();
  }, deps);
}

export function SecretsContextProvider({ storage, children }: SecretsContextProviderProps) {
  const [value, setValue] = useState({
    storage,
    async setItems(nextValues: SecretValues) {
      await storage.setItems(nextValues);
      setValue({ ...value });
    },
  });

  return <SecretsContext.Provider value={value}>{children}</SecretsContext.Provider>;
}

export function useSyncedSecretValues(
  initialValues?: SecretValues,
): [SecretValues, Dispatch<SecretValues>] {
  const { storage, setItems } = useContext(SecretsContext);
  const [values, setValues] = useState({ ...storage.getItems(), ...initialValues });

  useIdleCallbackEffect(() => {
    const nextSecretValues: SecretValues = pick(values, SYNCED_SECRET_VALUES);
    if (!isStorageEqual(storage.getItems(), nextSecretValues)) {
      setItems(nextSecretValues);
    }
  }, [values]);

  return [values, setValues];
}

export default SecretsContext;
