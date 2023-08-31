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
  flowPath: 'standard' as FlowPath,
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

  /**
   * Whether the doc type is clearly not supported type.
   */
  doc_type_supported: boolean;
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
  endpoint,
  statusEndpoint,
  statusPollInterval,
  formData = DEFAULT_FORM_DATA,
  flowPath,
  children,
}: UploadContextProviderProps) {
  const uploadWithFormData = (payload) => upload({ ...payload, ...formData }, { endpoint });

  const getStatus = () =>
    statusEndpoint
      ? upload({ ...formData }, { endpoint: statusEndpoint, method: 'PUT' })
      : Promise.reject();

  const value = useObjectMemo({
    upload: uploadWithFormData,
    getStatus,
    statusPollInterval,
    isMockClient,
    flowPath,
    formData,
  });

  return <UploadContext.Provider value={value}>{children}</UploadContext.Provider>;
}

export default UploadContext;
export { UploadContextProvider as Provider };
