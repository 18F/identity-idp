import React from 'react';
import userEvent from '@testing-library/user-event';
import { waitFor } from '@testing-library/dom';
import sinon from 'sinon';
import { AcuantProvider } from '@18f/identity-document-capture';
import SelfieStep, { validate } from '@18f/identity-document-capture/components/selfie-step';
import { RequiredValueMissingError } from '@18f/identity-document-capture/components/form-steps';
import render from '../../../support/render';
import { useAcuant } from '../../../support/acuant';

describe('document-capture/components/selfie-step', () => {
  const { initialize } = useAcuant();

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

  it('calls onChange callback with uploaded image', async () => {
    const onChange = sinon.stub();
    const { getByLabelText } = render(
      <AcuantProvider sdkSrc="about:blank">
        <SelfieStep onChange={onChange} />
      </AcuantProvider>,
    );
    initialize();
    window.AcuantPassiveLiveness.startSelfieCapture.callsArgWithAsync(0, '');

    userEvent.click(getByLabelText('doc_auth.headings.document_capture_selfie'));

    await waitFor(() => expect(onChange.getCall(0).args[0].selfie).to.be.instanceOf(window.Blob));
  });
});
