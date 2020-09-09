import React from 'react';
import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import { ACCEPTABLE_FILE_SIZE_BYTES } from '@18f/identity-document-capture/components/acuant-capture';
import SelfieStep, { validate } from '@18f/identity-document-capture/components/selfie-step';
import { RequiredValueMissingError } from '@18f/identity-document-capture/components/form-steps';
import render from '../../../support/render';
import { useSandbox } from '../../../support/sinon';

describe('document-capture/components/selfie-step', () => {
  const sandbox = useSandbox();

  beforeEach(() => {
    sandbox.stub(process.env, 'NODE_ENV').value('production');
    sandbox.stub(window.Blob.prototype, 'size').value(ACCEPTABLE_FILE_SIZE_BYTES);
  });

  describe('validate', () => {
    it('returns object with error if selfie is unset', () => {
      const value = {};
      const result = validate(value);

      expect(result).to.have.lengthOf(1);
      expect(result[0].field).to.equal('selfie');
      expect(result[0].error).to.be.instanceOf(RequiredValueMissingError);
    });

    it('returns empty array if selfie is set', () => {
      const value = {
        selfie: new window.File([], 'upload.png', { type: 'image/png' }),
      };
      const result = validate(value);

      expect(result).to.deep.equal([]);
    });
  });

  it('calls onChange callback with uploaded image', () => {
    const onChange = sinon.stub();
    const { getByLabelText } = render(<SelfieStep onChange={onChange} />);
    const file = new window.File([''], 'upload.png', { type: 'image/png' });

    userEvent.upload(getByLabelText('doc_auth.headings.document_capture_selfie'), file);

    expect(onChange.getCall(0).args[0]).to.deep.equal({ selfie: file });
  });
});
