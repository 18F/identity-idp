import { createContext } from 'react';
import { useObjectMemo } from '@18f/identity-react-hooks';
import defaultUpload from '../services/upload';

const UploadContext = createContext({
  upload: defaultUpload,
  getStatus: () => Promise.reject(),
  statusPollInterval: undefined,
  isMockClient: false,
  backgroundUploadURLs: {},
  backgroundUploadEncryptKey: undefined,
  flowPath: 'standard',
  csrf: null,
});

UploadContext.displayName = 'UploadContext';

type ReactNode = import('react').ReactNode;

type FlowPath = 'standard' | 'hybrid';

// Upload field error, after normalized to error instance.
interface UploadFieldError {
  //Field name
  field: 'front' | 'back' | 'selfie' | 'network';

  //Error message.
  message: string;
}

interface UploadOptions {
  // HTTP method to send payload.
  method?: 'POST' | 'PUT';

  // Endpoint to which payload should be sent.
  endpoint: string;

  // CSRF token to send as parameter to upload implementation.
  csrf: string;
}

interface UploadSuccessResponse {
  // Whether request was successful.
  success: true;

  // Whether verification result is still pending.
  isPending: boolean;
}

interface UploadErrorResponse {
  // Whether request was successful.
  success: false;

  // Error messages.
  errors: UploadFieldError[];

  // URL to which user should be redirected.
  redirect: string;

  // Number of remaining doc capture attempts for user.
  remaining_attempts: number;

  // Boolean to decide if capture hints should be shown with error.
  hints: boolean;
}

type UploadImplementation = (
  payload: Record<string, any>,
  options: UploadOptions,
) => Promise<UploadSuccessResponse>;

interface UploadContextProviderProps {
  // upload Custom upload implementation.
  upload: UploadImplementation;

  // Whether to treat upload as a mock implementation.
  isMockClient: boolean;

  //URLs to which payload values corresponding to
  backgroundUploadURLs: Record<string, string>;

  // Background upload encryption key.
  // key should be uploaded as soon as possible.
  backgroundUploadEncryptKey: CryptoKey;

  // Endpoint to which payload should be sent.
  endpoint: string;

  // Endpoint from which to request async upload status.
  statusEndpoint: string;

  // Interval at which to poll for status, in milliseconds.
  statusPollInterval: number;

  // HTTP method to send payload.
  method: 'POST' | 'PUT';

  // CSRF token to send as parameter to upload implementation.
  csrf: string;

  //Extra form data to merge into the payload before uploading
  formData: Record<string, any>;

  // The user's session flow path, one of "standard" or "hybrid".
  flowPath: FlowPath;

  // Child elements.
  children: ReactNode;
}

function UploadContextProvider({
  upload = defaultUpload,
  isMockClient = false,
  backgroundUploadURLs = {},
  backgroundUploadEncryptKey,
  endpoint,
  statusEndpoint,
  statusPollInterval,
  method,
  csrf,
  formData,
  flowPath,
  children,
}: UploadContextProviderProps) {
  const uploadWithCSRF = (payload) =>
    upload({ ...payload, ...formData }, { endpoint, method, csrf });

  const getStatus = () =>
    statusEndpoint
      ? upload({ ...formData }, { endpoint: statusEndpoint, method, csrf })
      : Promise.reject();

  const value = useObjectMemo({
    upload: uploadWithCSRF,
    getStatus,
    statusPollInterval,
    backgroundUploadURLs,
    backgroundUploadEncryptKey,
    isMockClient,
    flowPath,
    csrf,
  });

  return <UploadContext.Provider value={value}>{children}</UploadContext.Provider>;
}

export default UploadContext;
export { UploadContextProvider as Provider };
