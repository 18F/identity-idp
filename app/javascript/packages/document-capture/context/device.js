import { createContext } from 'react';

/**
 * @typedef DeviceContextValue
 *
 * @prop {boolean} isMobile Device is a mobile device.
 */

const DeviceContext = createContext(/** @type {DeviceContextValue} */ ({ isMobile: false }));

DeviceContext.displayName = 'DeviceContext';

export default DeviceContext;
