import { createContext, useState } from 'react';
import type { ReactNode } from 'react';

export type AddressVerificationMethod = 'phone' | 'gpo';

interface AddressVerificationMethodContextProviderProps {
  initialMethod?: AddressVerificationMethod;

  children?: ReactNode;
}

type AddressVerificationMethodContextValue = [
  addressVerificationMethod: AddressVerificationMethod,

  setAddressVerificationMethod: (nextMethod: AddressVerificationMethod) => void,
];

const DEFAULT_METHOD: AddressVerificationMethod = 'phone';

const AddressVerificationMethodContext = createContext<AddressVerificationMethodContextValue>([
  DEFAULT_METHOD,
  () => {},
]);

AddressVerificationMethodContext.displayName = 'AddressVerificationMethodContext';

export function AddressVerificationMethodContextProvider({
  initialMethod = DEFAULT_METHOD,
  children,
}: AddressVerificationMethodContextProviderProps) {
  const state = useState(initialMethod);

  return (
    <AddressVerificationMethodContext.Provider value={state}>
      {children}
    </AddressVerificationMethodContext.Provider>
  );
}

export default AddressVerificationMethodContext;
