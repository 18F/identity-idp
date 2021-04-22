import { createContext, useMemo } from 'react';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef ServiceProviderContext
 *
 * @prop {string?} name Service provider name.
 * @prop {string} failureToProofURL URL to redirect user on failure to proof.
 * @prop {(location: string) => string} getFailureToProofURL Returns failure to proof URL for a
 * specific location within the step.
 * @prop {boolean} isLivenessRequired Whether liveness capture should be expected from the user.
 */

const ServiceProviderContext = createContext(
  /** @type {ServiceProviderContext} */ ({
    name: null,
    failureToProofURL: '',
    getFailureToProofURL: () => '',
    isLivenessRequired: true,
  }),
);

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
      getFailureToProofURL(location) {
        const url = new URL(value.failureToProofURL);
        url.searchParams.set('location', location);
        return url.toString();
      },
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
