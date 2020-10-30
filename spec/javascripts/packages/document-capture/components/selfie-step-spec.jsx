import userEvent from '@testing-library/user-event';
import { waitFor } from '@testing-library/dom';
import sinon from 'sinon';
import { AcuantProvider } from '@18f/identity-document-capture';
import SelfieStep from '@18f/identity-document-capture/components/selfie-step';
import { render, useAcuant } from '../../../support/document-capture';

describe('document-capture/components/selfie-step', () => {
  const { initialize } = useAcuant();

  it('calls onChange callback with uploaded image', async () => {
    const onChange = sinon.stub();
    const { getByLabelText } = render(
      <AcuantProvider sdkSrc="about:blank">
        <SelfieStep onChange={onChange} />
      </AcuantProvider>,
    );
    initialize();
    window.AcuantPassiveLiveness.startSelfieCapture.callsArgWithAsync(0, '8J+Riw==');

    userEvent.click(getByLabelText('doc_auth.headings.document_capture_selfie'));

    await waitFor(() =>
      expect(onChange.getCall(0).args[0].selfie).to.equal('data:image/jpeg;base64,8J+Riw=='),
    );
  });
});
