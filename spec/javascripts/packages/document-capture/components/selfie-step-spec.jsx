import React from 'react';
import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import SelfieStep, { isValid } from '@18f/identity-document-capture/components/selfie-step';
import render from '../../../support/render';

describe('document-capture/components/selfie-step', () => {
  describe('isValid', () => {
    it('returns false if selfie is unset', () => {
      const value = {};
      const result = isValid(value);

      expect(result).to.be.false();
    });

    it('returns true if selfie is set', () => {
      const value = {
        selfie: new window.File([], 'upload.png', { type: 'image/png' }),
      };
      const result = isValid(value);

      expect(result).to.be.true();
    });
  });

  it('calls onChange callback with uploaded image', () => {
    const onChange = sinon.stub();
    const { getByLabelText } = render(<SelfieStep onChange={onChange} />);
    const file = new window.File([''], 'upload.png', { type: 'image/png' });

    userEvent.upload(getByLabelText('doc_auth.headings.document_capture_selfie'), file);

    expect(onChange.getCall(0).args[0]).to.deep.equal({ selfie: file });
  });

  it('restricts accepted file types', () => {
    const onChange = sinon.spy();
    const { getByLabelText } = render(<SelfieStep onChange={onChange} />);

    const input = getByLabelText('doc_auth.headings.document_capture_selfie');

    expect(input.getAttribute('accept')).to.equal('image/*');
  });
});
