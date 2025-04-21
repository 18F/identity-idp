import { createContext, useState } from 'react';
import { useObjectMemo } from '@18f/identity-react-hooks';
import type { ReactNode } from 'react';
import defaultUpload, { UploadFormEntriesError } from '../services/upload';
import type { PII } from '../services/upload';

const UploadContext = createContext({
  upload: defaultUpload,
  getStatus: () => Promise.resolve({} as UploadSuccessResponse),
  statusPollInterval: undefined as number | undefined,
  isMockClient: false,
  selectedIdType: '',
  flowPath: 'standard' as FlowPath,
  idType: 'state_id',
  formData: {} as Record<string, any>,
  submitAttempts: 0,
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
export interface ImageFingerprints {
  front: string[] | null;
  back: string[] | null;
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
  remaining_submit_attempts?: number;

  /**
   * Number of submitted doc capture attempts for user
   */
  submit_attempts?: number;

  /**
   * Boolean to decide if capture hints should be shown with error.
   */
  hints?: boolean;

  /**
   * Personally-identifiable information from OCR analysis.
   */
  ocr_pii?: PII;

  /**
   * Whether the unsuccessful result was any result other than passed or attention with barcode.
   */
  result_code_invalid: boolean;

  /**
   * Whether the unsuccessful result was the failure type.
   */
  result_failed: boolean;

  /**
   * Whether the selfie captured matched the image on the id.
   */
  selfie_status?: string;

  /**
   * Whether the doc type is clearly not supported type.
   */
  doc_type_supported: boolean;

  /*
   * Whether the selfie passed the liveness check from trueid
   */
  selfie_live?: boolean;

  /*
   * Whether the selfie passed the quality check from trueid.
   */
  selfie_quality_good?: boolean;

  /**
   * Record of failed image fingerprints
   */
  failed_image_fingerprints: ImageFingerprints | null;
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
   * The ID type, one of "state_id" or "passport".
   */
  idType: string;

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
  selectedIdType,
  formData = DEFAULT_FORM_DATA,
  flowPath,
  idType,
  children,
}: UploadContextProviderProps) {
  const [submitAttempts, setSubmitAttempts] = useState(0);

  const uploadWithFormData = async (payload) => {
    try {
      const result = await upload({ ...payload, ...formData }, { endpoint });
      return result;
    } catch (error) {
      if (error instanceof UploadFormEntriesError && error.submitAttempts !== undefined) {
        setSubmitAttempts(error.submitAttempts);
      }
      throw error;
    }
  };

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
    idType,
    formData,
    selectedIdType,
    submitAttempts,
  });

  return <UploadContext.Provider value={value}>{children}</UploadContext.Provider>;
}

export default UploadContext;
export { UploadContextProvider as Provider };
