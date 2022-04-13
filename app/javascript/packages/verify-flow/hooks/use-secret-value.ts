import { useContext } from 'react';
import SecretsContext from '../context/secrets-context';
import type { SecretValues } from '../context/secrets-context';

function useSecretValue<K extends keyof SecretValues>(
  key: K,
): [SecretValues[K], (nextValue: SecretValues[K]) => void] {
  const { storage, setItem } = useContext(SecretsContext);

  const setValue = (nextValue: SecretValues[K]) => setItem(key, nextValue);

  return [storage.getItem(key), setValue];
}

export default useSecretValue;
