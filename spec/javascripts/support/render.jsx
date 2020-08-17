import React from 'react';
import { render } from '@testing-library/react';
import sinon from 'sinon';
import UploadContext from '@18f/identity-document-capture/context/upload';

/**
 * @typedef RenderOptions
 *
 * @prop {boolean=} isUploadFailure Whether to simulate upload failure.
 */

/**
 * Pass-through to React Testing Library, which applies default context values
 * to stub behavior for testing environment.
 *
 * @see https://testing-library.com/docs/react-testing-library/setup#custom-render
 *
 * @param {import('react').ReactElement} element Element to render.
 * @param {RenderOptions=}               options Optional options.
 *
 * @return {import('@testing-library/react').RenderResult}
 */
function renderWithDefaultContext(element, options = {}) {
  const { isUploadFailure } = options;

  const upload = sinon
    .stub()
    .onCall(0)
    .callsFake((payload) =>
      isUploadFailure ? Promise.reject(new Error('Failure!')) : Promise.resolve(payload),
    )
    .onCall(1)
    .throws();

  return render(<UploadContext.Provider value={upload}>{element}</UploadContext.Provider>);
}

export default renderWithDefaultContext;
