import { createContext } from 'react';
import type { ReactNode } from 'react';
import useCounter from '../hooks/use-counter';

interface NativeCameraABTestContextInterface {
  /**
   * Whether or not the Acuant SDK should be bypassed and only the native camera
   * offered to the user.
   */
  nativeCameraOnly: boolean;
}

const NativeCameraABTestContext = createContext<NativeCameraABTestContextInterface>({
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
