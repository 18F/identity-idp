import React from 'react';
import { render } from '@testing-library/react';
import sinon from 'sinon';
import UploadContext from '../../../app/javascript/app/document-capture/context/upload';

/**
 * Pass-through to React Testing Library, which applies default context values
 * to stub behavior for testing environment.
 *
 * @see https://testing-library.com/docs/react-testing-library/setup#custom-render
 *
 * @param {import('react').ReactElement} element Element to render.
 *
 * @return {import('@testing-library/react').RenderResult}
 */
function renderWithDefaultContext(element) {
  const upload = sinon
    .stub()
    .onCall(0)
    .callsFake((payload) => Promise.resolve(payload))
    .onCall(1)
    .throws();

  return render(<UploadContext.Provider value={upload}>{element}</UploadContext.Provider>);
}

export default renderWithDefaultContext;
