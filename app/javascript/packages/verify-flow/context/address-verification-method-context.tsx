import { createContext, useState } from 'react';
import type { ReactNode } from 'react';

/**
 * Mechanisms by which a user can verify their address.
 */
export type AddressVerificationMethod = 'phone' | 'gpo';

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
type AddressVerificationMethodContextValue = [
  /**
   * Current address verification method.
   */
  addressVerificationMethod: AddressVerificationMethod,

  /**
   * Setter to update to a new address verification method.
   */
  setAddressVerificationMethod: (nextMethod: AddressVerificationMethod) => void,
];

/**
 * Default address verification method.
 */
const DEFAULT_METHOD: AddressVerificationMethod = 'phone';

/**
 * Address verification method context container.
 */
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
