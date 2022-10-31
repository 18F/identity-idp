import { createContext } from 'react';
import { useObjectMemo } from '@18f/identity-react-hooks';
import type { ReactNode } from 'react';
import defaultUpload from '../services/upload';
import type { PII } from '../services/upload';

const UploadContext = createContext({
  upload: defaultUpload,
  getStatus: () => Promise.resolve({} as UploadSuccessResponse),
  statusPollInterval: undefined as number | undefined,
  isMockClient: false,
  backgroundUploadURLs: {} as Record<string, string>,
  backgroundUploadEncryptKey: undefined as CryptoKey | undefined,
  flowPath: 'standard' as FlowPath,
  csrf: null as string | null,
  formData: {} as Record<string, any>,
});

UploadContext.displayName = 'UploadContext';

export type FlowPath = 'standard' | 'hybrid';

/**
 * Upload field error, after normalized to error instance.
 */
export interface UploadFieldError {
  /**
   * Field name
   */
  field: 'front' | 'back' | 'network';

  /**
   * Error message.
   */
  message: string;
}

interface UploadOptions {
  /**
   * HTTP method to send payload.
   */
  method?: 'POST' | 'PUT';

  /**
   * Endpoint to which payload should be sent.
   */
  endpoint: string;

  /**
   * CSRF token to send as parameter to upload implementation.
   */
  csrf: string | null;
}

export interface UploadSuccessResponse {
  /**
   * Whether request was successful.
   */
  success: true;

  /**
   * Whether verification result is still pending.
   */
  isPending: boolean;
}

export interface UploadErrorResponse {
  /**
   * Whether request was successful.
   */
  success: false;

  /**
   * Error messages.
   */
  errors?: UploadFieldError[];

  /**
   * URL to which user should be redirected.
   */
  redirect?: string;

  /**
   * Number of remaining doc capture attempts for user.
   */
  remaining_attempts?: number;

  /**
   * Boolean to decide if capture hints should be shown with error.
   */
  hints?: boolean;

  /**
   * Personally-identifiable information from OCR analysis.
   */
  ocr_pii?: PII;

  /**
   * Whether the unsuccessful result was the failure type.
   */
  result_failed: boolean;
}

export type UploadImplementation = (
  payload: Record<string, any>,
  options: UploadOptions,
) => Promise<UploadSuccessResponse>;

interface UploadContextProviderProps {
  /**
   * Custom upload implementation.
   */
  upload?: UploadImplementation;

  /**
   * Whether to treat upload as a mock implementation.
   */
  isMockClient?: boolean;

  /**
   * URLs to which payload values corresponding to key should be uploaded as soon as possible.
   */
  backgroundUploadURLs: Record<string, string>;

  /**
   * Background upload encryption key.
   */
  backgroundUploadEncryptKey?: CryptoKey;

  /**
   * Endpoint to which payload should be sent.
   */
  endpoint: string;

  /**
   * Endpoint from which to request async upload status.
   */
  statusEndpoint?: string;

  /**
   * Interval at which to poll for status, in milliseconds.
   */
  statusPollInterval?: number;

  /**
   * CSRF token to send as parameter to upload implementation.
   */
  csrf: string | null;

  /**
   * Extra form data to merge into the payload before uploading
   */
  formData?: Record<string, any>;

  /**
   * The user's session flow path, one of "standard" or "hybrid".
   */
  flowPath: FlowPath;

  /**
   *  Child elements.
   */
  children: ReactNode;
}

/**
 * Default form data. Assigned as a constant to avoid creating a new object reference for each call
 * to the component.
 */
const DEFAULT_FORM_DATA = {};

function UploadContextProvider({
  upload = defaultUpload,
  isMockClient = false,
  backgroundUploadURLs = {},
  backgroundUploadEncryptKey,
  endpoint,
  statusEndpoint,
  statusPollInterval,
  csrf,
  formData = DEFAULT_FORM_DATA,
  flowPath,
  children,
}: UploadContextProviderProps) {
  const uploadWithCSRF = (payload) => upload({ ...payload, ...formData }, { endpoint, csrf });

  const getStatus = () =>
    statusEndpoint
      ? upload({ ...formData }, { endpoint: statusEndpoint, method: 'PUT', csrf })
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
    formData,
  });

  return <UploadContext.Provider value={value}>{children}</UploadContext.Provider>;
}

export default UploadContext;
export { UploadContextProvider as Provider };
