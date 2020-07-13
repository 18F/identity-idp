import React from 'react';
import { render } from '@testing-library/react';
import DocumentCapture from '../../../../../app/javascript/app/document-capture/components/document-capture';
import { useDOM } from '../../../support/dom';

describe('document-capture/components/document-capture', () => {
  useDOM();

  it('renders', () => {
    const { getByText } = render(<DocumentCapture />);

    const button = getByText('doc_auth.headings.welcome');
    expect(button).to.be.ok();
  });
});
