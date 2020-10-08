import { createContext } from 'react';

/**
 * @typedef ServiceProviderContext
 *
 * @prop {string?} name Service provider name.
 * @prop {string?} failureToProofURL URL to redirect user on failure to proof.
 * @prop {boolean} isLivenessRequired Whether liveness capture should be expected from the user.
 */

const ServiceProviderContext = createContext(
  /** @type {ServiceProviderContext} */ ({
    name: null,
    failureToProofURL: null,
    isLivenessRequired: true,
  }),
);

export default ServiceProviderContext;
