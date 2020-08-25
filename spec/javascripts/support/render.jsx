import React from 'react';
import { render } from '@testing-library/react';
import sinon from 'sinon';
import { UploadContextProvider } from '@18f/identity-document-capture';

/** @typedef {import('@testing-library/react').RenderOptions} BaseRenderOptions */

/**
 * @typedef RenderOptions
 *
 * @prop {Error=} uploadError Whether to simulate upload failure.
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
function renderWithDefaultContext(element, options = {}) {
  const { uploadError, expectedUploads = 1, ...baseRenderOptions } = options;

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

  const result = render(
    <UploadContextProvider upload={upload}>{element}</UploadContextProvider>,
    baseRenderOptions,
  );

  return {
    ...result,
    rerender(nextElement, nextOptions) {
      renderWithDefaultContext(nextElement, { ...nextOptions, container: result.container });
    },
  };
}

export default renderWithDefaultContext;
