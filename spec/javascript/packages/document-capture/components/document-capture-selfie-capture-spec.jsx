import { expect } from 'chai';
import { within } from '@testing-library/react';
import DocumentCaptureSelfieCapture from '@18f/identity-document-capture/components/document-capture-selfie-capture';
import { render } from '../../../support/document-capture';

describe('document-capture/components/document-capture-selfie-capture', () => {
  it('renders the form steps', () => {
    const { getAllByRole, getByText } = render(
      <DocumentCaptureSelfieCapture
        value={{}}
        onChange={() => {}}
        errors={[]}
        onError={() => {}}
        registerField={() => undefined}
      />,
    );

    const header = getByText('2. doc_auth.headings.document_capture_subheader_selfie');
    expect(header).to.be.ok();
    const tipListHeader = getByText('doc_auth.tips.document_capture_selfie_selfie_text');
    expect(tipListHeader).to.be.ok();
    const lists = getAllByRole('list');
    const tipList = lists[0];
    expect(tipList).to.be.ok();
    const tipListItem = within(tipList).getAllByRole('listitem');
    tipListItem.forEach((li, idx) => {
      expect(li.textContent).to.equals(`doc_auth.tips.document_capture_selfie_text${idx + 1}`);
    });
  });
});
