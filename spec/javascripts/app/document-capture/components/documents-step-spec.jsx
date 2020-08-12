import React from 'react';
import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import render from '../../../support/render';
import DeviceContext from '../../../../../app/javascript/app/document-capture/context/device';
import DocumentsStep from '../../../../../app/javascript/app/document-capture/components/documents-step';
import DataURLFile from '../../../../../app/javascript/app/document-capture/models/data-url-file';

describe('document-capture/components/documents-step', () => {
  it('renders with front and back inputs', () => {
    const { getByLabelText } = render(<DocumentsStep />);

    const front = getByLabelText('doc_auth.headings.document_capture_front');
    const back = getByLabelText('doc_auth.headings.document_capture_back');

    expect(front).to.be.ok();
    expect(back).to.be.ok();
  });

  it('calls onChange callback with uploaded image', (done) => {
    const onChange = sinon.stub();
    const { getByLabelText } = render(<DocumentsStep onChange={onChange} />);
    const file = new window.File([''], 'upload.png', { type: 'image/png' });

    userEvent.upload(getByLabelText('doc_auth.headings.document_capture_front'), file);

    onChange.callsFake((nextValue) => {
      expect(nextValue).to.deep.equal({
        front_image: new DataURLFile('data:image/png;base64,', 'upload.png'),
      });
      done();
    });
  });

  it('restricts accepted file types', () => {
    const onChange = sinon.spy();
    const { getByLabelText } = render(<DocumentsStep onChange={onChange} />);

    const input = getByLabelText('doc_auth.headings.document_capture_front');

    expect(input.getAttribute('accept')).to.equal('image/*');
  });

  it('renders device-specific instructions', () => {
    let { getByText } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <DocumentsStep />
      </DeviceContext.Provider>,
    );

    expect(() => getByText('doc_auth.tips.document_capture_id_text4')).to.throw();

    getByText = render(<DocumentsStep />).getByText;

    expect(() => getByText('doc_auth.tips.document_capture_id_text4')).not.to.throw();
  });
});
