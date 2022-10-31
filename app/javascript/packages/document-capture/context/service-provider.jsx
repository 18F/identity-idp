import { createContext, useMemo } from 'react';
import { addSearchParams } from '@18f/identity-url';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef ServiceProviderContext
 *
 * @prop {string?} name Service provider name.
 * @prop {string} failureToProofURL URL to redirect user on failure to proof.
 * @prop {(location: string) => string} getFailureToProofURL Returns failure to proof URL for a
 * specific location within the step.
 */

const ServiceProviderContext = createContext(
  /** @type {ServiceProviderContext} */ ({
    name: null,
    failureToProofURL: '',
    getFailureToProofURL: () => '',
  }),
);

ServiceProviderContext.displayName = 'ServiceProviderContext';

/**
 * @typedef ServiceProviderContextProviderProps
 *
 * @prop {Omit<ServiceProviderContext, 'getFailureToProofURL'>} value
 * @prop {ReactNode} children
 */

/**
 * @param {ServiceProviderContextProviderProps} props
 */
function ServiceProviderContextProvider({ value, children }) {
  const mergedValue = useMemo(
    () => ({
      ...value,
      getFailureToProofURL: (location) => addSearchParams(value.failureToProofURL, { location }),
    }),
    [value],
  );

  return (
    <ServiceProviderContext.Provider value={mergedValue}>
      {children}
    </ServiceProviderContext.Provider>
  );
}

export default ServiceProviderContext;
export { ServiceProviderContextProvider as Provider };
