import { createContext } from 'react';

/**
 * @typedef ServiceProviderContext
 *
 * @prop {string} name Service provider name.
 * @prop {string} failureToProofURL URL to redirect user on failure to proof.
 */

const ServiceProviderContext = createContext(/** @type {ServiceProviderContext=} */ (undefined));

export default ServiceProviderContext;
