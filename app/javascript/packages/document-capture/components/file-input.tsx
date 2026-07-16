import {
  useContext,
  useState,
  useMemo,
  forwardRef,
  useRef,
  useImperativeHandle,
  ForwardedRef,
} from 'react';
import type {
  MouseEvent as ReactMouseEvent,
  DragEvent as ReactDragEvent,
  ChangeEvent as ReactChangeEvent,
  ReactNode,
} from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { SpinnerDots } from '@18f/identity-components';
import { useInstanceId } from '@18f/identity-react-hooks';
import FileImage from './file-image';
import StatusMessage, { Status } from './status-message';
import DeviceContext from '../context/device';
import usePrevious from '../hooks/use-previous';

interface FileInputProps {
  label: string;
  hint?: string;
  bannerText: string;
  invalidTypeText: string;
  fileUpdatedText: string;
  fileLoadingText: string;
  fileLoadedText: string;
  accept?: string[];
  value: Blob | string | null | undefined;
  errorMessage?: ReactNode;
  isValuePending?: boolean;
  onClick?: (event: ReactMouseEvent) => void;
  onDrop?: (event: ReactDragEvent) => void;
  onChange?: (nextValue: File | null) => void;
  onError?: (message: ReactNode) => void;
  capture?: 'user' | 'environment';
}

/**
 * Given a token of an file input accept attribute, returns an equivalent regular expression
 * pattern, or undefined if a pattern cannot be determined.
 */
export function getAcceptPattern(accept: string): RegExp | undefined {
  switch (accept) {
    case 'audio/*':
    case 'video/*':
    case 'image/*': {
      const [type] = accept.split('/');
      return new RegExp(`^${type}/.+`);
    }

    default:
      return /^[\w-]+\/[\w-]+$/.test(accept) ? new RegExp(`^${accept}$`) : undefined;
  }
}

export function isImage(value: Blob | string): boolean {
  if (value instanceof window.Blob) {
    const pattern: RegExp | undefined = getAcceptPattern('image/*');
    if (pattern) {
      return pattern.test(value.type);
    }
    return false;
  }

  return /^data:image\//.test(value);
}

export function isValidForAccepts(mimeType: string, accept?: string[]): boolean {
  return (
    !accept || accept.map(getAcceptPattern).some((pattern) => pattern && pattern.test(mimeType))
  );
}

interface AriaDescribedbyArguments {
  hint: string | undefined;
  hintId: string;
  shownErrorMessage: ReactNode | string | undefined;
  errorId: string;
  successMessage: string | undefined;
  successId: string;
}
function getAriaDescribedby({
  hint,
  hintId,
  shownErrorMessage,
  errorId,
  successMessage,
  successId,
}: AriaDescribedbyArguments) {
  const errorMessageShown = !!shownErrorMessage;
  const successMessageShown = !errorMessageShown && successMessage;
  const optionalHintId = hint ? hintId : undefined;

  if (errorMessageShown) {
    return optionalHintId ? `${errorId} ${optionalHintId}` : errorId;
  }
  if (successMessageShown) {
    return optionalHintId ? `${successId} ${optionalHintId}` : successId;
  }
  return optionalHintId;
}

function FileInput(props: FileInputProps, ref: ForwardedRef<any>) {
  const {
    label,
    hint,
    bannerText,
    invalidTypeText,
    fileUpdatedText,
    fileLoadingText,
    fileLoadedText,
    accept,
    value,
    errorMessage,
    isValuePending,
    onClick,
    onDrop,
    onChange = () => {},
    onError = () => {},
    capture,
  } = props;
  const inputRef = useRef<HTMLInputElement>(null);
  const { t, formatHTML } = useI18n();
  const instanceId = useInstanceId();
  const { isMobile } = useContext(DeviceContext);
  const [isDraggingOver, setIsDraggingOver] = useState(false);
  const previousValue = usePrevious(value);
  const previousIsValuePending = usePrevious(isValuePending);
  const isUpdated = useMemo(
    () => Boolean(previousValue && value && previousValue !== value),
    [value],
  );
  const isPendingValueReceived = useMemo(
    () => previousIsValuePending && !isValuePending && !!value,

    [value, isValuePending, previousIsValuePending],
  );
  const [ownErrorMessage, setOwnErrorMessage] = useState<string | null>(null);
  useMemo(() => setOwnErrorMessage(null), [value]);
  useImperativeHandle(ref, () => inputRef.current);
  const inputId = `file-input-${instanceId}`;
  const hintId = `${inputId}-hint`;
  const errorId = `${inputId}-error`;
  const successId = `${inputId}-success`;
  const innerHintId = `${hintId}-inner`;
  const labelId = `${inputId}-label`;
  const showInnerHint: boolean = !value && !isValuePending && !isMobile;
  const isYAMLFile: boolean = value instanceof window.File && value.name.endsWith('.yml');
  const isIdCapture: boolean = !(label === t('doc_auth.headings.document_capture_selfie'));

  function onChangeIfValid(event: ReactChangeEvent<HTMLInputElement>) {
    if (!event.target.files) {
      return;
    }

    const file: File = event.target.files[0];
    if (file) {
      if (isValidForAccepts(file.type, accept)) {
        onChange(file);
      } else {
        const nextOwnErrorMessage = invalidTypeText;
        setOwnErrorMessage(nextOwnErrorMessage);
        onError(nextOwnErrorMessage);
      }
    } else {
      onChange(null);
    }
  }

  const shownErrorMessage = errorMessage ?? ownErrorMessage;

  let successMessage: string | undefined;
  if (isUpdated) {
    successMessage = fileUpdatedText;
  } else if (isValuePending) {
    successMessage = fileLoadingText;
  } else if (isPendingValueReceived) {
    successMessage = fileLoadedText;
  }

  const ariaDescribedby = getAriaDescribedby({
    hint,
    hintId,
    shownErrorMessage,
    errorId,
    successMessage,
    successId,
  });

  return (
    <div
      className={[
        (shownErrorMessage || isUpdated) && 'ads-form-group',
        shownErrorMessage && 'ads-form-group--error',
        isUpdated && !shownErrorMessage && 'ads-form-group--success',
      ]
        .filter(Boolean)
        .join(' ')}
    >
      <label
        id={labelId}
        htmlFor={inputId}
        className={['ads-label', shownErrorMessage && 'ads-label--error'].filter(Boolean).join(' ')}
      >
        {label}
      </label>
      {hint && (
        <span className="ads-hint" id={hintId}>
          {hint}
        </span>
      )}

      <StatusMessage status={Status.ERROR} id={errorId}>
        {shownErrorMessage}
      </StatusMessage>

      <span
        className={
          successMessage === fileLoadingText || successMessage === fileLoadedText
            ? 'ads-sr-only'
            : undefined
        }
      >
        <StatusMessage
          id={successId}
          status={Status.SUCCESS}
          className={
            successMessage === fileLoadingText || successMessage === fileLoadedText
              ? 'ads-sr-only'
              : undefined
          }
        >
          {!shownErrorMessage && successMessage}
        </StatusMessage>
      </span>

      <div
        className={[
          'ads-file-input ads-file-input--single-value',
          isDraggingOver && 'ads-file-input--drag',
          value && !isValuePending && 'ads-file-input--has-value',
          isValuePending && 'ads-file-input--value-pending',
          isIdCapture && 'ads-file-input--is-id-capture',
        ]
          .filter(Boolean)
          .join(' ')}
        onDragOver={() => setIsDraggingOver(true)}
        onDragLeave={() => setIsDraggingOver(false)}
        onDrop={() => setIsDraggingOver(false)}
      >
        <div className="ads-file-input__target">
          {value && !isValuePending && (!isMobile || isYAMLFile) && (
            <div className="ads-file-input__preview-heading">
              <span>
                {value instanceof window.File && (
                  <>
                    <span className="ads-sr-only">{t('doc_auth.forms.selected_file')}: </span>
                    {value.name}{' '}
                  </>
                )}
              </span>
              <span className="ads-file-input__choose">{t('doc_auth.forms.change_file')}</span>
            </div>
          )}
          {value && !isValuePending && isImage(value) && (
            <div className="ads-file-input__preview" aria-hidden="true">
              {value instanceof window.Blob ? (
                <FileImage file={value} alt="" className="ads-file-input__preview-image" />
              ) : (
                <img src={value} alt="" className="ads-file-input__preview-image" />
              )}
            </div>
          )}
          {!value && !isValuePending && (
            <div className="ads-file-input__instructions" aria-hidden="true">
              <strong className="ads-file-input__banner-text">{bannerText}</strong>
              {showInnerHint && (
                <span className="ads-file-input__drag-text" id={innerHintId}>
                  {formatHTML(t('doc_auth.forms.choose_file_html'), {
                    'lg-underline': ({ children }) => (
                      <span className="ads-file-input__choose">{children}</span>
                    ),
                  })}
                </span>
              )}
            </div>
          )}
          <div className="ads-file-input__box">
            {isValuePending && <SpinnerDots isCentered className="text-base" />}
          </div>

          <input
            ref={inputRef}
            id={inputId}
            className="ads-file-input__input"
            type="file"
            aria-busy={isValuePending}
            onChange={onChangeIfValid}
            onClick={onClick}
            onDrop={onDrop}
            accept={accept ? accept.join() : undefined}
            capture={capture}
            aria-describedby={ariaDescribedby}
          />
        </div>
      </div>
    </div>
  );
}

export default forwardRef(FileInput);
