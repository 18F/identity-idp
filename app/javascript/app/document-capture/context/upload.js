import { createContext } from 'react';
import upload from '../services/upload';

const UploadContext = createContext(upload);

export default UploadContext;
