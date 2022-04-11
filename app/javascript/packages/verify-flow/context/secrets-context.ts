import { createContext } from 'react';
import SecretSessionStorage from '@18f/identity-secret-session-storage';

export type SecretValues = {
  example: string;
};

const SecretsContext = createContext(new SecretSessionStorage<SecretValues>());

export const { Provider: SecretsContextProvider } = SecretsContext;
export default SecretsContext;
