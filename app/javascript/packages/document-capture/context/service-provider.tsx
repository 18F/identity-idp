import { createContext, useMemo } from 'react';
import { addSearchParams } from '@18f/identity-url';
import type { ReactNode } from 'react';

export interface ServiceProviderContextType {
  /**
   * Service provider name
   */
  name: string | null;
  /**
   * URL to redirect user on failure to proof.
   */
  failureToProofURL: string;
  /**
   * Returns failure to proof URL for a
   * specific location within the step.
   */
  getFailureToProofURL: (location: string) => string;
  /**
   * Whether or not the selfie feature is currently on
   */
  selfieCaptureEnabled?: Boolean;
}

const ServiceProviderContext = createContext<ServiceProviderContextType>({
  name: null,
  failureToProofURL: '',
  getFailureToProofURL: () => '',
  selfieCaptureEnabled: false,
});

ServiceProviderContext.displayName = 'ServiceProviderContext';

interface ServiceProviderContextProviderProps {
  value: Omit<ServiceProviderContextType, 'getFailurreToProofURL'>;
  selfieCaptureEnabled?: Boolean;
  children: ReactNode;
}

function ServiceProviderContextProvider({
  value,
  selfieCaptureEnabled,
  children,
}: ServiceProviderContextProviderProps) {
  const mergedValue = useMemo(
    () => ({
      ...value,
      selfieCaptureEnabled,
      getFailureToProofURL: (location: string) =>
        addSearchParams(value.failureToProofURL, { location }),
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
