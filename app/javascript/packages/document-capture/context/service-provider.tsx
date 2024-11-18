import { createContext, useMemo } from 'react';
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
}

const ServiceProviderContext = createContext<ServiceProviderContextType>({
  name: null,
  failureToProofURL: '',
});

ServiceProviderContext.displayName = 'ServiceProviderContext';

interface ServiceProviderContextProviderProps {
  value: Omit<ServiceProviderContextType, 'getFailurreToProofURL'>;
  children: ReactNode;
}

function ServiceProviderContextProvider({ value, children }: ServiceProviderContextProviderProps) {
  const mergedValue = useMemo(
    () => ({
      ...value,
    }),
    [value],
  );

  return <ServiceProviderContext.Provider value={mergedValue}>{children}</ServiceProviderContext.Provider>;
}

export default ServiceProviderContext;
export { ServiceProviderContextProvider as Provider };
