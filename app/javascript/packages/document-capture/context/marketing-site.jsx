import { createContext } from 'react';

/**
 * @typedef MarketingSiteContext
 *
 * @prop {string} documentCaptureTipsURL Link to Help Center article with tips for document capture.
 * @prop {string} supportedDocumentsURL Link to Help Center article detailing supported documents.
 */

const MarketingSiteContext = createContext(
  /** @type {MarketingSiteContext} */ ({ documentCaptureTipsURL: '', supportedDocumentsURL: '' }),
);

MarketingSiteContext.displayName = 'MarketingSiteContext';

export default MarketingSiteContext;
