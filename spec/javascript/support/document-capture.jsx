import { render as baseRender, cleanup } from '@testing-library/react';
import sinon from 'sinon';
// @ts-ignore
import { UploadContextProvider } from '@18f/identity-document-capture';

/** @typedef {import('@testing-library/react').RenderOptions} BaseRenderOptions */

/**
 * @typedef RenderOptions
 *
 * @prop {Error=} uploadError Whether to simulate upload failure.
 * @prop {boolean=} isMockClient Whether to treat upload as a mock implementation.
 * @prop {number=} expectedUploads Number of times upload is expected to be called. Defaults to `1`.
 */

/**
 * Pass-through to React Testing Library, which applies default context values
 * to stub behavior for testing environment.
 *
 * @see https://testing-library.com/docs/react-testing-library/setup#custom-render
 *
 * @param {import('react').ReactElement} element Element to render.
 * @param {RenderOptions&BaseRenderOptions=} options Optional options.
 *
 * @return {import('@testing-library/react').RenderResult}
 */
export function render(element, options = {}) {
  const { uploadError, expectedUploads = 1, isMockClient = true, ...baseRenderOptions } = options;

  const upload = sinon
    .stub()
    .callsFake((payload) => (uploadError ? Promise.reject(uploadError) : Promise.resolve(payload)))
    .onCall(expectedUploads)
    .throws(
      new Error(
        `Expected upload to have been called at most ${expectedUploads} times. It was called ${
          expectedUploads + 1
        } times.`,
      ),
    );

  const defaultBaseWrapper = ({ children }) => children;
  const { wrapper: baseWrapper = defaultBaseWrapper } = baseRenderOptions;

  return baseRender(element, {
    ...baseRenderOptions,
    wrapper: ({ children }) => (
      // @ts-ignore
      <UploadContextProvider upload={upload} isMockClient={isMockClient}>
        {
          // @ts-ignore
          baseWrapper({ children })
        }
      </UploadContextProvider>
    ),
  });
}

export function useAcuant() {
  afterEach(() => {
    // While React Testing Library will perform this automatically, it must to occur prior to
    // resetting the global variables, since otherwise the component's effect unsubscribe will
    // attempt to reference globals that no longer exist.
    cleanup();
    // @ts-ignore
    delete window.AcuantJavascriptWebSdk;
    // @ts-ignore
    delete window.AcuantCamera;
    // @ts-ignore
    delete window.AcuantCameraUI;
    // @ts-ignore
    delete window.AcuantPassiveLiveness;
    // @ts-ignore
    delete window.loadAcuantSdk;
  });

  return {
    initialize({
      isSuccess = true,
      isCameraSupported = true,
      start = sinon.stub(),
      end = sinon.stub(),
      selfieStart = sinon.stub(),
      selfieEnd = sinon.stub(),
      triggerCapture = sinon.stub(),
    } = {}) {
      window.AcuantJavascriptWebSdk = {
        // @ts-ignore
        initialize: (_credentials, _endpoint, { onSuccess, onFail }) =>
          isSuccess ? onSuccess() : onFail(401, 'Server returned a 401 (missing credentials).'),
        start: sinon.stub().callsArg(0),
        START_FAIL_CODE: 'start-fail-code',
        REPEAT_FAIL_CODE: 'repeat-fail-code',
        SEQUENCE_BREAK_CODE: 'sequence-break-code',
        setUnexpectedErrorCallback: sinon.stub(),
      };
      // @ts-ignore
      window.AcuantCamera = { isCameraSupported, triggerCapture };
      window.AcuantCameraUI = {
        start: sinon.stub().callsFake((...args) => {
          const camera = document.getElementById('acuant-camera');
          const canvas = document.createElement('canvas');
          canvas.id = 'acuant-ui-canvas';
          // @ts-ignore
          camera.appendChild(canvas);
          // @ts-ignore
          camera.dispatchEvent(new window.CustomEvent('acuantcameracreated'));
          start(...args);
        }),
        end,
      };
      window.AcuantPassiveLiveness = { start: selfieStart, end: selfieEnd };
      window.loadAcuantSdk = () => {};
      const sdkScript = document.querySelector('[data-acuant-sdk]');
      // @ts-ignore
      sdkScript.onload();
      // @ts-ignore
      sdkScript.onload = null;
    },
  };
}

/**
 * Prepares test environment to behave as document capture form page, returning `onSubmit` Sinon
 * mock instance of page form.
 *
 * @return {import('sinon').SinonMockStatic}
 */
export function useDocumentCaptureForm() {
  const onSubmit = sinon.mock();
  let form;

  beforeEach(() => {
    onSubmit.reset();

    form = document.createElement('form');
    form.className = 'js-document-capture-form';
    form.addEventListener('submit', (event) => {
      event.preventDefault();
      onSubmit();
    });
    sinon.stub(form, 'submit').callsFake(onSubmit);
    document.body.appendChild(form);
  });

  afterEach(() => {
    if ([...document.body.childNodes].includes(form)) {
      document.body.removeChild(form);
    }
    form.submit.restore();
  });

  return onSubmit;
}
