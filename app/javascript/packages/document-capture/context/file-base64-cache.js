import { createContext } from 'react';

const FileBase64CacheContext = createContext(/** @type {WeakMap<Blob,string>} */ (new WeakMap()));

export default FileBase64CacheContext;
