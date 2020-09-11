import React from 'react';
import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import { ACCEPTABLE_FILE_SIZE_BYTES } from '@18f/identity-document-capture/components/acuant-capture';
import DeviceContext from '@18f/identity-document-capture/context/device';
import DocumentsStep, { validate } from '@18f/identity-document-capture/components/documents-step';
import { RequiredValueMissingError } from '@18f/identity-document-capture/components/form-steps';
import render from '../../../support/render';
import { useSandbox } from '../../../support/sinon';

describe('document-capture/components/documents-step', () => {
  const sandbox = useSandbox();

  beforeEach(() => {
    sandbox.stub(window.Blob.prototype, 'size').value(ACCEPTABLE_FILE_SIZE_BYTES);
  });

  describe('validate', () => {
    it('returns errors if both front and back are unset', () => {
      const value = {};
      const result = validate(value);

      expect(result).to.have.lengthOf(2);
      expect(result[0].field).to.equal('front');
      expect(result[0].error).to.be.instanceOf(RequiredValueMissingError);
      expect(result[1].field).to.equal('back');
      expect(result[1].error).to.be.instanceOf(RequiredValueMissingError);
    });

    it('returns error if one of front and back are unset', () => {
      const value = { front: new window.File([], 'upload.png', { type: 'image/png' }) };
      const result = validate(value);

      expect(result).to.have.lengthOf(1);
      expect(result[0].field).to.equal('back');
      expect(result[0].error).to.be.instanceOf(RequiredValueMissingError);
    });

    it('returns empty array if both front and back are set', () => {
      const value = {
        front: new window.File([], 'upload.png', { type: 'image/png' }),
        back: new window.File([], 'upload.png', { type: 'image/png' }),
      };
      const result = validate(value);

      expect(result).to.deep.equal([]);
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
