import { useContext, useState } from 'react';
import SecretsContext from '../context/secrets-context';
import type { SecretValues } from '../context/secrets-context';

function useSecretValue<K extends keyof SecretValues>(
  key: K,
): [SecretValues[K], (nextValue: SecretValues[K]) => void] {
  const store = useContext(SecretsContext);
  const [value, setValue] = useState(store.getItem(key));

  function setStateValue(nextValue: SecretValues[K]) {
    store.setItem(key, nextValue);
    setValue(nextValue);
  }

  return [value, setStateValue];
}

export default useSecretValue;
