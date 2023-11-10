import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import { expect } from 'chai';
import { t } from '@18f/identity-i18n';
import {
  DeviceContext,
  UploadContextProvider,
  FailedCaptureAttemptsContextProvider,
  FeatureFlagContext,
} from '@18f/identity-document-capture';
import DocumentsStep from '@18f/identity-document-capture/components/documents-step';
import { composeComponents } from '@18f/identity-compose-components';
import { render } from '../../../support/document-capture';
import { getFixtureFile } from '../../../support/file';

describe('document-capture/components/documents-step', () => {
  it('renders with front and back inputs', () => {
    const { getByLabelText } = render(<DocumentsStep />);

    const front = getByLabelText('doc_auth.headings.document_capture_front');
    const back = getByLabelText('doc_auth.headings.document_capture_back');

    expect(front).to.be.ok();
    expect(back).to.be.ok();
  });

  it('calls onChange callback with uploaded image', async () => {
    const onChange = sinon.stub();
    const { getByLabelText } = render(
      <FailedCaptureAttemptsContextProvider
        maxCaptureAttemptsBeforeNativeCamera={3}
        maxSubmissionAttemptsBeforeNativeCamera={3}
      >
        <DocumentsStep onChange={onChange} />,
      </FailedCaptureAttemptsContextProvider>,
    );
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

  it('renders optional question part', () => {
    const { getByRole, getByText } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <UploadContextProvider flowPath="standard">
          <DocumentsStep />
        </UploadContextProvider>
      </DeviceContext.Provider>,
    );
    expect(getByRole('heading', { name: 'doc_auth.exit_survey.header', level: 2 })).to.be.ok();
    expect(getByText('doc_auth.exit_survey.optional.button')).to.be.ok();
  });

  context('not ready section', () => {
    it('is rendered when enabled', () => {
      const App = composeComponents(
        [
          FeatureFlagContext.Provider,
          {
            value: {
              notReadySectionEnabled: true,
            },
          },
        ],
        [DocumentsStep],
      );
      const { getByRole } = render(<App />);
      expect(getByRole('heading', { name: 'doc_auth.not_ready.header', level: 2 })).to.be.ok();
      const button = getByRole('button', { name: 'doc_auth.not_ready.button_nosp' });
      expect(button).to.be.ok();
    });
    it('is not rendered when disabled', () => {
      const App = composeComponents(
        [
          FeatureFlagContext.Provider,
          {
            value: {
              notReadySectionEnabled: false,
            },
          },
        ],
        [DocumentsStep],
      );
      const { queryByRole } = render(<App />);
      expect(queryByRole('heading', { name: 'doc_auth.not_ready.header', level: 2 })).to.be.null();
    });
  });
});
