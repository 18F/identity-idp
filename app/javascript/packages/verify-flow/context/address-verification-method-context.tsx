import { createContext, useState } from 'react';
import { useObjectMemo } from '@18f/identity-react-hooks';
import type { ReactNode } from 'react';

/**
 * Mechanisms by which a user can verify their address.
 */
export type AddressVerificationMethod = 'phone' | 'gpo' | null;

/**
 * Context provider props.
 */
interface AddressVerificationMethodContextProviderProps {
  /**
   * Optional initial context value.
   */
  initialMethod?: AddressVerificationMethod;

  /**
   * Context children.
   */
  children?: ReactNode;
}

/**
 * Context value.
 */
interface AddressVerificationMethodContextValue {
  /**
   * Current address verification method.
   */
  addressVerificationMethod: AddressVerificationMethod;

  /**
   * Setter to update to a new address verification method.
   */
  setAddressVerificationMethod: (nextMethod: AddressVerificationMethod) => void;
}

/**
 * Default address verification method.
 */
const DEFAULT_METHOD: AddressVerificationMethod = null;

/**
 * Address verification method context container.
 */
const AddressVerificationMethodContext = createContext<AddressVerificationMethodContextValue>({
  addressVerificationMethod: DEFAULT_METHOD,
  setAddressVerificationMethod: () => {},
});

AddressVerificationMethodContext.displayName = 'AddressVerificationMethodContext';

export function AddressVerificationMethodContextProvider({
  initialMethod = DEFAULT_METHOD,
  children,
}: AddressVerificationMethodContextProviderProps) {
  const [addressVerificationMethod, setAddressVerificationMethod] = useState(initialMethod);
  const value = useObjectMemo({ addressVerificationMethod, setAddressVerificationMethod });

  return (
    <AddressVerificationMethodContext.Provider value={value}>
      {children}
    </AddressVerificationMethodContext.Provider>
  );
}

export default AddressVerificationMethodContext;
