import { createContext } from 'react';
import type { ReactNode } from 'react';

interface NativeCameraABTestContextValue {
  /**
   * Whether or not the A/B testing of the native camera only option is enabled.
   */
  nativeCameraABTestingEnabled: boolean;
  /**
   * Whether or not the Acuant SDK should be bypassed and only the native camera
   * offered to the user.
   */
  nativeCameraOnly: boolean;
}

const NativeCameraABTestContext = createContext<NativeCameraABTestContextValue>({
  nativeCameraABTestingEnabled: false,
  nativeCameraOnly: false,
});

NativeCameraABTestContext.displayName = 'NativeCameraABTestContext';

interface NativeCameraABTestContextProviderProps {
  children: ReactNode;
  nativeCameraABTestingEnabled: boolean;
  nativeCameraOnly: boolean;
}

function NativeCameraABTestContextProvider({
  children,
  nativeCameraABTestingEnabled,
  nativeCameraOnly,
}: NativeCameraABTestContextProviderProps) {
  return (
    <NativeCameraABTestContext.Provider
      value={{
        nativeCameraOnly,
        nativeCameraABTestingEnabled,
      }}
    >
      {children}
    </NativeCameraABTestContext.Provider>
  );
}

export default NativeCameraABTestContext;
export { NativeCameraABTestContextProvider as Provider };
