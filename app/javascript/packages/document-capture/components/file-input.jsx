import {
  useContext,
  useState,
  useMemo,
  useEffect,
  forwardRef,
  useRef,
  useImperativeHandle,
} from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { SpinnerDots } from '@18f/identity-components';
import { useInstanceId } from '@18f/identity-react-hooks';
import FileImage from './file-image';
import StatusMessage, { Status } from './status-message';
import DeviceContext from '../context/device';
import usePrevious from '../hooks/use-previous';

/** @typedef {import('react').MouseEvent} ReactMouseEvent */
/** @typedef {import('react').DragEvent} ReactDragEvent */
/** @typedef {import('react').ChangeEvent} ReactChangeEvent */
/** @typedef {import('react').RefAttributes} ReactRefAttributes */
/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef FileInputProps
 *
 * @prop {string} label Input label.
 * @prop {string=} hint Optional hint text.
 * @prop {string=} bannerText Optional banner overlay text.
 * @prop {string} invalidTypeText Error message text to show on invalid file type selection.
 * @prop {string} fileUpdatedText Success message text to show when selected file is updated.
 * @prop {string} fileLoadingText Status message text to show when file is pending.
 * @prop {string} fileLoadedText Status message text to show once pending file is loaded.
 * @prop {string[]=} accept Optional array of file input accept patterns.
 * @prop {Blob|string|null|undefined} value Current value.
 * @prop {ReactNode=} errorMessage Error to show.
 * @prop {boolean=} isValuePending Whether to show the input in an indeterminate loading state,
 * pending an incoming value.
 * @prop {(event:ReactMouseEvent)=>void=} onClick Input click handler.
 * @prop {(event:ReactDragEvent)=>void=} onDrop Input drop handler.
 * @prop {(nextValue:File?)=>void=} onChange Input change handler.
 * @prop {(message:ReactNode)=>void=} onError Callback to trigger if upload error occurs.
 */

/**
 * Given a token of an file input accept attribute, returns an equivalent regular expression
 * pattern, or undefined if a pattern cannot be determined. This is an approximation, and not fully
 * spec-compliant to allowable characters in what is considered a valid MIME type.
 *
 * @see https://html.spec.whatwg.org/multipage/input.html#attr-input-accept
 * @see https://tools.ietf.org/html/rfc7231#section-3.1.1.1
 * @see https://tools.ietf.org/html/rfc2045#section-5.1
 *
 * @param {string} accept Accept token.
 *
 * @return {RegExp=} Regular expression, or undefined if cannot be determined.
 */
export function getAcceptPattern(accept) {
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

/**
 * Returns true if the given file represents an image, or false otherwise.
 *
 * @param {Blob|string} value File value to test.
 *
 * @return {boolean} Whether given file is an image.
 */
export function isImage(value) {
  if (value instanceof window.Blob) {
    const pattern = /** @type {RegExp} */ (getAcceptPattern('image/*'));
    return pattern.test(value.type);
  }

  return /^data:image\//.test(value);
}

/**
 * Returns true if the given MIME type is valid for the array of accept tokens or if the accept
 * parameter is empty. Returns false otherwise.
 *
 * @param {string}    mimeType MIME type to test.
 * @param {string[]=} accept   Accept tokens.
 *
 * @return {boolean} Whether file is valid.
 */
export function isValidForAccepts(mimeType, accept) {
  return (
    !accept || accept.map(getAcceptPattern).some((pattern) => pattern && pattern.test(mimeType))
  );
}

/**
 * @param {FileInputProps} props Props object.
 * @param {import('react').ForwardedRef<any>} ref
 */
function FileInput(props, ref) {
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
  } = props;
  const isResettingValue = useRef(false);
  const inputRef = useRef(/** @type {HTMLInputElement?} */ (null));
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
  const [ownErrorMessage, setOwnErrorMessage] = useState(/** @type {string?} */ (null));
  useMemo(() => setOwnErrorMessage(null), [value]);
  useImperativeHandle(ref, () => inputRef.current);
  useEffect(() => {
    // This is not a controlled component in the sense that the value is reflected onto the input
    // element. Clear any DOM value that happens to be set, so that the browser doesn't suppress a
    // change event based on what it assumes the current value to be.
    //
    // "In React, an <input type="file" /> is always an uncontrolled component because its value can
    // only be set by a user, and not programmatically."
    //
    // See: https://reactjs.org/docs/uncontrolled-components.html#the-file-input-tag
    if (inputRef.current && inputRef.current.files?.length) {
      isResettingValue.current = true;
      inputRef.current.value = '';
      isResettingValue.current = false;
    }
  }, [value]);
  const inputId = `file-input-${instanceId}`;
  const hintId = `${inputId}-hint`;
  const innerHintId = `${hintId}-inner`;

  /**
   * In response to a file input change event, confirms that the file is valid before calling
   * `onChange`.
   *
   * @param {import('react').ChangeEvent<HTMLInputElement>} event Change event.
   */
  function onChangeIfValid(event) {
    // It should not be expected to need to consider the value reset, since the HTML specification
    // dictates that programmatic updates to values are excluded from event emissions. Alas, IE11
    // _does_ emit a change event when assigning or resetting the value of a file input.
    //
    // "These events are not fired in response to changes made to the values of form controls by
    // scripts."
    //
    // See: https://html.spec.whatwg.org/multipage/input.html
    if (isResettingValue.current) {
      return;
    }

    const file = /** @type {FileList} */ (event.target.files)[0];
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

  /**
   * @param {string} fileLabel String velue of the label for input to display
   * @param {Blob|string|null|undefined} fileValue File or string for which to generate label.
   */
  function getLabelFromValue(fileLabel, fileValue) {
    if (fileValue instanceof window.File) {
      return `${fileLabel} - ${fileValue.name}`;
    }
    if (fileValue) {
      return `${fileLabel} - ${t('doc_auth.forms.captured_image')}`;
    }
    return '';
  }

  const shownErrorMessage = errorMessage ?? ownErrorMessage;

  /** @type {string=} */
  let successMessage;
  if (isUpdated) {
    successMessage = fileUpdatedText;
  } else if (isValuePending) {
    successMessage = fileLoadingText;
  } else if (isPendingValueReceived) {
    successMessage = fileLoadedText;
  }

  return (
    <div
      className={[
        (shownErrorMessage || isUpdated) && 'usa-form-group',
        shownErrorMessage && 'usa-form-group--error',
        isUpdated && !shownErrorMessage && 'usa-form-group--success',
      ]
        .filter(Boolean)
        .join(' ')}
    >
      {/*
       * Disable reason: The Airbnb configuration of the `jsx-a11y` rule is strict in that it
       * requires _both_ the `for` attribute and nesting, to maximize support for assistive
       * technology. By the standard, only one or the other should be required. A form layout which
       * includes a hint following a label cannot be nested within the label without misidentifying
       * the hint as part of the label, which is the markup currently supported by USWDS.
       *
       * See: https://github.com/jsx-eslint/eslint-plugin-jsx-a11y/issues/718
       * See: https://github.com/airbnb/javascript/pull/2136
       */}
      {/* eslint-disable-next-line jsx-a11y/label-has-associated-control */}
      <label
        htmlFor={inputId}
        className={['usa-label', shownErrorMessage && 'usa-label--error'].filter(Boolean).join(' ')}
      >
        {label}
      </label>
      {hint && (
        <span className="usa-hint" id={hintId}>
          {hint}
        </span>
      )}
      <StatusMessage status={Status.ERROR}>{shownErrorMessage}</StatusMessage>
      <StatusMessage
        status={Status.SUCCESS}
        className={
          successMessage === fileLoadingText || successMessage === fileLoadedText
            ? 'usa-sr-only'
            : undefined
        }
      >
        {!shownErrorMessage && successMessage}
      </StatusMessage>
      <div
        className={[
          'usa-file-input usa-file-input--single-value',
          isDraggingOver && 'usa-file-input--drag',
          value && !isValuePending && 'usa-file-input--has-value',
          isValuePending && 'usa-file-input--value-pending',
        ]
          .filter(Boolean)
          .join(' ')}
        onDragOver={() => setIsDraggingOver(true)}
        onDragLeave={() => setIsDraggingOver(false)}
        onDrop={() => setIsDraggingOver(false)}
      >
        <div className="usa-file-input__target">
          {value && !isValuePending && !isMobile && (
            <div className="usa-file-input__preview-heading">
              <span>
                {value instanceof window.File && (
                  <>
                    <span className="usa-sr-only">{t('doc_auth.forms.selected_file')}: </span>
                    {value.name}{' '}
                  </>
                )}
              </span>
              <span className="usa-file-input__choose">{t('doc_auth.forms.change_file')}</span>
            </div>
          )}
          {value && !isValuePending && isImage(value) && (
            <div className="usa-file-input__preview" aria-hidden="true">
              {value instanceof window.Blob ? (
                <FileImage file={value} alt="" className="usa-file-input__preview-image" />
              ) : (
                <img src={value} alt="" className="usa-file-input__preview-image" />
              )}
            </div>
          )}
          {!value && !isValuePending && (
            <div className="usa-file-input__instructions" aria-hidden="true">
              {bannerText && <strong className="usa-file-input__banner-text">{bannerText}</strong>}
              {isMobile && bannerText ? null : (
                <span className="usa-file-input__drag-text" id={innerHintId}>
                  {formatHTML(t('doc_auth.forms.choose_file_html'), {
                    'lg-underline': ({ children }) => (
                      <span className="usa-file-input__choose">{children}</span>
                    ),
                  })}
                </span>
              )}
            </div>
          )}
          <div className="usa-file-input__box">
            {isValuePending && <SpinnerDots isCentered className="text-base" />}
          </div>
          <input
            ref={inputRef}
            id={inputId}
            className="usa-file-input__input"
            type="file"
            aria-label={getLabelFromValue(label, value)}
            aria-busy={isValuePending}
            onChange={onChangeIfValid}
            capture={capture}
            onClick={onClick}
            onDrop={onDrop}
            accept={accept ? accept.join() : undefined}
            aria-describedby={hint ? `${innerHintId} ${hintId}` : undefined}
          />
        </div>
      </div>
    </div>
  );
}

export default forwardRef(FileInput);
