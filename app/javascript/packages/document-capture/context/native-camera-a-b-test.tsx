import { createContext } from 'react';
import type { ReactNode } from 'react';

interface NativeCameraABTestContextValue {
  /**
   * Whether or not the Acuant SDK should be bypassed and only the native camera
   * offered to the user.
   */
  nativeCameraOnly: boolean;
}

const NativeCameraABTestContext = createContext<NativeCameraABTestContextValue>({
  nativeCameraOnly: false,
});

NativeCameraABTestContext.displayName = 'NativeCameraABTestContext';

interface NativeCameraABTestContextProviderProps {
  children: ReactNode;
  nativeCameraOnly: boolean;
}

function NativeCameraABTestContextProvider({
  children,
  nativeCameraOnly,
}: NativeCameraABTestContextProviderProps) {
  return (
    <NativeCameraABTestContext.Provider
      value={{
        nativeCameraOnly,
      }}
    >
      {children}
    </NativeCameraABTestContext.Provider>
  );
}

export default NativeCameraABTestContext;
export { NativeCameraABTestContextProvider as Provider };
