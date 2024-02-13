import { createContext } from 'react';

const FileBase64CacheContext = createContext(new WeakMap<Blob, string>());

FileBase64CacheContext.displayName = 'FileBase64CacheContext';

export default FileBase64CacheContext;
