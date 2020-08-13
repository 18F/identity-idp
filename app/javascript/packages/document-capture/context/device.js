import { createContext } from 'react';

/**
 * @typedef DeviceContext
 *
 * @prop {boolean} isMobile Device is a mobile device.
 */

const DeviceContext = createContext(/** @type {DeviceContext} */ ({ isMobile: false }));

export default DeviceContext;
