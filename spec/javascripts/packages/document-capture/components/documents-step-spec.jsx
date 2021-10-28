import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import {
  DeviceContext,
  ServiceProviderContextProvider,
  FailedCaptureAttemptsContextProvider,
  AcuantContextProvider,
} from '@18f/identity-document-capture';
import { I18nContext } from '@18f/identity-react-i18n';
import DocumentsStep from '@18f/identity-document-capture/components/documents-step';
import { render, useAcuant } from '../../../support/document-capture';
import { getFixtureFile } from '../../../support/file';

describe('document-capture/components/documents-step', () => {
  const { initialize } = useAcuant();

  it('renders with front and back inputs', () => {
    const { getByLabelText } = render(<DocumentsStep />);

    const front = getByLabelText('doc_auth.headings.document_capture_front');
    const back = getByLabelText('doc_auth.headings.document_capture_back');

    expect(front).to.be.ok();
    expect(back).to.be.ok();
  });

  it('calls onChange callback with uploaded image', async () => {
    const onChange = sinon.stub();
    const { getByLabelText } = render(<DocumentsStep onChange={onChange} />);
    const file = await getFixtureFile('doc_auth_images/id-back.jpg');

    userEvent.upload(getByLabelText('doc_auth.headings.document_capture_front'), file);
    await new Promise((resolve) => onChange.callsFake(resolve));
    expect(onChange).to.have.been.calledWith({
      front: file,
      front_image_metadata: sinon.match(/^\{.+\}$/),
    });
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

  it('renders additional tips after failed attempts', () => {
    const { getByLabelText, getByText, getByRole } = render(
      <FailedCaptureAttemptsContextProvider maxFailedAttemptsBeforeTips={2}>
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
            <DocumentsStep onChange={() => {}} />
          </AcuantContextProvider>
        </DeviceContext.Provider>
      </FailedCaptureAttemptsContextProvider>,
    );

    initialize();
    const result = { sharpness: 100, image: { data: '' } };

    window.AcuantCameraUI.start.callsFake(({ onCropped }) => onCropped({ ...result, glare: 10 }));
    userEvent.click(getByLabelText('doc_auth.headings.document_capture_front'));

    // Reset after successful attempt.
    window.AcuantCameraUI.start.callsFake(({ onCropped }) => onCropped({ ...result, glare: 80 }));
    userEvent.click(getByLabelText('doc_auth.headings.document_capture_front'));

    // Fail twice more to trigger troubleshooting.
    window.AcuantCameraUI.start.callsFake(({ onCropped }) => onCropped({ ...result, glare: 10 }));
    userEvent.click(getByLabelText('doc_auth.headings.document_capture_front'));
    userEvent.click(getByLabelText('doc_auth.headings.document_capture_front'));

    getByText(
      'doc_auth.tips.capture_troubleshooting_glare doc_auth.tips.capture_troubleshooting_lead',
    );

    userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

    // Only show troubleshooting a single time, even after 2 more failed attempts.
    userEvent.click(getByLabelText('doc_auth.headings.document_capture_front'));
    userEvent.click(getByLabelText('doc_auth.headings.document_capture_front'));
    expect(() =>
      getByText(
        'doc_auth.tips.capture_troubleshooting_glare doc_auth.tips.capture_troubleshooting_lead',
      ),
    ).to.throw();
  });

  context('service provider context', () => {
    it('renders with name and help link', () => {
      const { getByText } = render(
        <I18nContext.Provider
          value={{
            'doc_auth.info.get_help_at_sp_html':
              '<strong>Having trouble?</strong> Get help at %{sp_name}',
          }}
        >
          <ServiceProviderContextProvider
            value={{
              name: 'Example App',
              failureToProofURL: 'https://example.com/?step=document_capture',
              isLivenessRequired: false,
            }}
          >
            <DocumentsStep />
          </ServiceProviderContextProvider>
        </I18nContext.Provider>,
      );

      const help = getByText('Having trouble?').closest('a');

      expect(help).to.be.ok();
      expect(help.href).to.equal(
        'https://example.com/?step=document_capture&location=documents_having_trouble',
      );
    });
  });

  context('mobile', () => {
    it('does not show document step footer', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <DocumentsStep />
        </DeviceContext.Provider>,
      );

      expect(() => getByText('doc_auth.info.document_capture_upload_image')).to.throw();
    });
  });

  context('desktop', () => {
    it('shows document step footer', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: false }}>
          <DocumentsStep />
        </DeviceContext.Provider>,
      );

      expect(getByText('doc_auth.info.document_capture_upload_image')).to.be.ok();
    });
  });
});
