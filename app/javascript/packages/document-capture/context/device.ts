import { createContext } from 'react';

interface DeviceContextValue {
  // Device is a mobile device.
  isMobile: Boolean;
}

const DeviceContext = createContext<DeviceContextValue>({ isMobile: false });

DeviceContext.displayName = 'DeviceContext';

export default DeviceContext;
