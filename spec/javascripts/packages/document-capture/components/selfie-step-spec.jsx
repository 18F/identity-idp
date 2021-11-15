import userEvent from '@testing-library/user-event';
import { waitFor } from '@testing-library/dom';
import sinon from 'sinon';
import { AcuantContextProvider, DeviceContext } from '@18f/identity-document-capture';
import SelfieStep from '@18f/identity-document-capture/components/selfie-step';
import { render, useAcuant } from '../../../support/document-capture';

describe('document-capture/components/selfie-step', () => {
  context('mobile', () => {
    const { initialize } = useAcuant();

    it('calls onChange callback with uploaded image', async () => {
      const onChange = sinon.stub();
      const { getByLabelText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <SelfieStep onChange={onChange} />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );
      initialize();
      window.AcuantPassiveLiveness.startSelfieCapture.callsArgWithAsync(0, '8J+Riw==');

      userEvent.click(getByLabelText('doc_auth.headings.document_capture_selfie'));

      await waitFor(() =>
        expect(onChange.getCall(0).args[0].selfie).to.equal('data:image/jpeg;base64,8J+Riw=='),
      );
    });
  });

  context('desktop', () => {
    it('calls onChange callback with uploaded image', async () => {
      const onChange = sinon.stub();
      const { getByLabelText } = render(
        <DeviceContext.Provider value={{ isMobile: false }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <SelfieStep onChange={onChange} />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      const file = new window.File([], 'image.png', { type: 'image/png' });
      userEvent.upload(getByLabelText('doc_auth.headings.document_capture_selfie'), file);

      await waitFor(() => expect(onChange.getCall(0).args[0].selfie).to.equal(file));
    });
  });
});
