import React from 'react';
import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import DeviceContext from '@18f/identity-document-capture/context/device';
import DocumentsStep, { isValid } from '@18f/identity-document-capture/components/documents-step';
import render from '../../../support/render';

describe('document-capture/components/documents-step', () => {
  describe('isValid', () => {
    it('returns false if both front and back are unset', () => {
      const value = {};
      const result = isValid(value);

      expect(result).to.be.false();
    });

    it('returns false if one of front and back are unset', () => {
      const value = { front: new window.File([], 'upload.png', { type: 'image/png' }) };
      const result = isValid(value);

      expect(result).to.be.false();
    });

    it('returns true if both front and back are set', () => {
      const value = {
        front: new window.File([], 'upload.png', { type: 'image/png' }),
        back: new window.File([], 'upload.png', { type: 'image/png' }),
      };
      const result = isValid(value);

      expect(result).to.be.true();
    });
  });

  it('renders with front and back inputs', () => {
    const { getByLabelText } = render(<DocumentsStep />);

    const front = getByLabelText('doc_auth.headings.document_capture_front');
    const back = getByLabelText('doc_auth.headings.document_capture_back');

    expect(front).to.be.ok();
    expect(back).to.be.ok();
  });

  it('calls onChange callback with uploaded image', () => {
    const onChange = sinon.stub();
    const { getByLabelText } = render(<DocumentsStep onChange={onChange} />);
    const file = new window.File([''], 'upload.png', { type: 'image/png' });

    userEvent.upload(getByLabelText('doc_auth.headings.document_capture_front'), file);
    expect(onChange.getCall(0).args[0]).to.deep.equal({ front: file });
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
