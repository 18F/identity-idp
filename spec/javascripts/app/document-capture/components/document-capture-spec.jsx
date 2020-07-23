import React from 'react';
import render from '../../../support/render';
import DocumentCapture from '../../../../../app/javascript/app/document-capture/components/document-capture';

describe('document-capture/components/document-capture', () => {
  it('renders a heading', () => {
    const { getByText } = render(<DocumentCapture />);

    const heading = getByText('doc_auth.headings.welcome');

    expect(heading).to.be.ok();
  });
});
