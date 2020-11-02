import React from 'react';
import { render as baseRender, act, cleanup } from '@testing-library/react';
import sinon from 'sinon';
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
      <UploadContextProvider upload={upload} isMockClient={isMockClient}>
        {baseWrapper({ children })}
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
    delete window.AcuantJavascriptWebSdk;
    delete window.AcuantCamera;
    delete window.AcuantCameraUI;
    delete window.AcuantPassiveLiveness;
  });

  return {
    initialize({
      isSuccess = true,
      isCameraSupported = true,
      start = sinon.stub(),
      end = sinon.stub(),
      startSelfieCapture = sinon.stub(),
    } = {}) {
      window.AcuantJavascriptWebSdk = {
        initialize: (_credentials, _endpoint, { onSuccess, onFail }) =>
          isSuccess ? onSuccess() : onFail(),
      };
      window.AcuantCamera = { isCameraSupported };
      window.AcuantCameraUI = { start, end };
      window.AcuantPassiveLiveness = { startSelfieCapture };
      act(window.onAcuantSdkLoaded);
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
    document.body.appendChild(form);
  });

  afterEach(() => {
    if ([...document.body.childNodes].includes(form)) {
      document.body.removeChild(form);
    }
  });

  return onSubmit;
}
