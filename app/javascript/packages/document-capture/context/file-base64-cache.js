import { createContext } from 'react';

const FileBase64Cache = createContext(/** @type {WeakMap<Blob,string>} */ (new WeakMap()));

export default FileBase64Cache;
