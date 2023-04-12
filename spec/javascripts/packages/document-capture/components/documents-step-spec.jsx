import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import { t } from '@18f/identity-i18n';
import {
  DeviceContext,
  ServiceProviderContextProvider,
  FailedCaptureAttemptsContextProvider,
  AcuantContextProvider,
  UploadContextProvider,
} from '@18f/identity-document-capture';
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

    await Promise.all([
      new Promise((resolve) => onChange.callsFake(resolve)),
      userEvent.upload(getByLabelText('doc_auth.headings.document_capture_front'), file),
    ]);
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

  it('renders additional tips after failed attempts', async () => {
    const { getByLabelText, getByText, findByRole } = render(
      <FailedCaptureAttemptsContextProvider maxFailedAttemptsBeforeTips={2}>
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <DocumentsStep onChange={() => {}} />
          </AcuantContextProvider>
        </DeviceContext.Provider>
      </FailedCaptureAttemptsContextProvider>,
    );

    initialize();
    const result = { sharpness: 100, image: { data: '' } };

    window.AcuantCameraUI.start.callsFake(({ onCropped }) => onCropped({ ...result, glare: 10 }));
    await userEvent.click(getByLabelText('doc_auth.headings.document_capture_front'));

    // Reset after successful attempt.
    window.AcuantCameraUI.start.callsFake(({ onCropped }) => onCropped({ ...result, glare: 80 }));
    await userEvent.click(getByLabelText('doc_auth.headings.document_capture_front'));

    // Fail twice more to trigger troubleshooting.
    window.AcuantCameraUI.start.callsFake(({ onCropped }) => onCropped({ ...result, glare: 10 }));
    await userEvent.click(getByLabelText('doc_auth.headings.document_capture_front'));
    await userEvent.click(getByLabelText('doc_auth.headings.document_capture_front'));

    getByText(
      'doc_auth.tips.capture_troubleshooting_glare doc_auth.tips.capture_troubleshooting_lead',
    );

    await userEvent.click(await findByRole('button', { name: 'idv.failure.button.warning' }));

    // Only show troubleshooting a single time, even after 2 more failed attempts.
    await userEvent.click(getByLabelText('doc_auth.headings.document_capture_front'));
    await userEvent.click(getByLabelText('doc_auth.headings.document_capture_front'));
    expect(() =>
      getByText(
        'doc_auth.tips.capture_troubleshooting_glare doc_auth.tips.capture_troubleshooting_lead',
      ),
    ).to.throw();
  });

  it('renders troubleshooting options', () => {
    const { getByRole } = render(
      <ServiceProviderContextProvider
        value={{
          name: 'Example App',
          failureToProofURL: 'https://example.com/?step=document_capture',
        }}
      >
        <DocumentsStep />
      </ServiceProviderContextProvider>,
    );

    expect(
      getByRole('heading', { name: 'components.troubleshooting_options.default_heading' }),
    ).to.be.ok();
    expect(
      getByRole('link', { name: 'idv.troubleshooting.options.get_help_at_sp links.new_window' })
        .href,
    ).to.equal(
      'https://example.com/?step=document_capture&location=document_capture_troubleshooting_options',
    );
  });

  it('renders the hybrid flow warning if the flow is hybrid', () => {
    const { getByText } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <UploadContextProvider flowPath="hybrid">
          <DocumentsStep />
        </UploadContextProvider>
      </DeviceContext.Provider>,
    );
    const expectedText = t('doc_auth.hybrid_flow_warning.explanation_non_sp_html');

    expect(getByText(expectedText)).to.exist();
  });

  it('does not render the hybrid flow warning if the flow is standard (default)', () => {
    const { queryByText } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <UploadContextProvider flowPath="standard">
          <DocumentsStep />
        </UploadContextProvider>
      </DeviceContext.Provider>,
    );
    const notExpectedText = t('doc_auth.hybrid_flow_warning.explanation_non_sp_html');

    expect(queryByText(notExpectedText)).to.not.exist();
  });
});
