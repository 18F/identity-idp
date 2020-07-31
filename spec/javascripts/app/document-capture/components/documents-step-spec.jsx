import React from 'react';
import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import render from '../../../support/render';
import DeviceContext from '../../../../../app/javascript/app/document-capture/context/device';
import DocumentsStep from '../../../../../app/javascript/app/document-capture/components/documents-step';

describe('document-capture/components/documents-step', () => {
  it('renders with front and back inputs', () => {
    const { getByLabelText } = render(<DocumentsStep />);

    const front = getByLabelText('doc_auth.headings.upload_front');
    const back = getByLabelText('doc_auth.headings.upload_back');

    expect(front).to.be.ok();
    expect(back).to.be.ok();
  });

  it('calls onChange callback with uploaded image', () => {
    const onChange = sinon.spy();
    const { getByLabelText } = render(<DocumentsStep onChange={onChange} />);
    const file = new window.File([''], 'upload.png', { type: 'image/png' });

    userEvent.upload(getByLabelText('doc_auth.headings.upload_front'), file);

    expect(onChange.calledOnce).to.be.true();
    expect(onChange.getCall(0).args[0]).to.deep.equal({ front_image: file });
  });

  it('restricts accepted file types', () => {
    const onChange = sinon.spy();
    const { getByLabelText } = render(<DocumentsStep onChange={onChange} />);

    const input = getByLabelText('doc_auth.headings.upload_front');

    // Ideally this wouldn't be so tightly-coupled with the DOM implementation, but instead attempt
    // to upload a file of an invalid type. `@testing-library/user-event` doesn't currently support
    // this usage.
    //
    // See: https://github.com/testing-library/user-event/issues/421
    expect(input.getAttribute('accept')).to.equal('image/*');
  });

  it('renders device-specific instructions', () => {
    let { getByText } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <DocumentsStep />
      </DeviceContext.Provider>,
    );

    expect(() => getByText('doc_auth.instructions.document_capture_id_text4')).to.throw();

    getByText = render(<DocumentsStep />).getByText;

    expect(() => getByText('doc_auth.instructions.document_capture_id_text4')).not.to.throw();
  });
});
