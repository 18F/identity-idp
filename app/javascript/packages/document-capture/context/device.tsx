import { createContext, ReactNode } from 'react';
import { useObjectMemo } from '@18f/identity-react-hooks';

export interface DeviceContextValue {
  children: ReactNode;
  isMobile: boolean;
}

const DeviceContext = createContext({
  isMobile: false,
  detectCameraResolution: () => {},
});

DeviceContext.displayName = 'DeviceContext';

function DeviceContextProvider({ isMobile, children }: DeviceContextValue) {
  const detectCameraResolution = () => {
    console.log('camera resolution detected');
  };

  const value = useObjectMemo({
    isMobile,
    detectCameraResolution,
  });

  return <DeviceContext.Provider value={value}>{children}</DeviceContext.Provider>;
}

export default DeviceContext;
export { DeviceContextProvider as Provider };
