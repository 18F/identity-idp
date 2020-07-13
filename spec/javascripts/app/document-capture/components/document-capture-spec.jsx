import React from 'react';
import { render } from '@testing-library/react';
import DocumentCapture from '../../../../../app/javascript/app/document-capture/components/document-capture';
import { useDOM } from '../../../support/dom';

describe('document-capture/components/document-capture', () => {
  useDOM();

  it('renders', () => {
    const { getByAltText } = render(<DocumentCapture />);

    const img = getByAltText('doc_auth.headings.welcome');
    expect(img).to.be.ok();
  });
});
