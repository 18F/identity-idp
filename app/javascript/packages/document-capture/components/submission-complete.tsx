import { useState, useContext, useRef } from 'react';
import CallbackOnMount from './callback-on-mount';
import UploadContext from '../context/upload';
import type { UploadSuccessResponse } from '../context/upload';

interface Resource<T> {
  /**
   * Resource reader.
   */
  read: () => T;
}

interface SubmissionCompleteProps {
  /**
   * Resource object.
   */
  resource: Resource<UploadSuccessResponse>;
}

export class RetrySubmissionError extends Error {}

function SubmissionComplete({ resource }: SubmissionCompleteProps) {
  const [, setRetryError] = useState<Error | undefined>(undefined);
  const sleepTimeout = useRef<number>();
  const { statusPollInterval } = useContext(UploadContext);
  const response = resource.read();

  function handleResponse() {
    if (response.isPending) {
      if (Number.isFinite(statusPollInterval)) {
        sleepTimeout.current = window.setTimeout(() => {
          setRetryError(() => {
            throw new RetrySubmissionError();
          });
        }, statusPollInterval);
      }
    } else {
      const form = document.querySelector<HTMLFormElement>('.js-document-capture-form');
      form?.submit();
    }

    return () => window.clearTimeout(sleepTimeout.current);
  }

  return <CallbackOnMount onMount={handleResponse} />;
}

export default SubmissionComplete;
