import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import { expect } from 'chai';
import { t } from '@18f/identity-i18n';
import {
  DeviceContext,
  UploadContextProvider,
  FailedCaptureAttemptsContextProvider,
  SelfieCaptureContext,
} from '@18f/identity-document-capture';
import DocumentsStep from '@18f/identity-document-capture/components/documents-step';
import { render } from '../../../support/document-capture';
import { getFixtureFile } from '../../../support/file';

describe('document-capture/components/documents-step', () => {
  it('renders with only front and back inputs by default', () => {
    const { getByLabelText, queryByLabelText } = render(
      <DocumentsStep
        value={{}}
        onChange={() => undefined}
        errors={[]}
        onError={() => undefined}
        registerField={() => undefined}
        unknownFieldErrors={[]}
        toPreviousStep={() => undefined}
      />,
    );

    const front = getByLabelText('doc_auth.headings.document_capture_front');
    const back = getByLabelText('doc_auth.headings.document_capture_back');
    const selfie = queryByLabelText('doc_auth.headings.document_capture_selfie');

    expect(front).to.be.ok();
    expect(back).to.be.ok();
    expect(selfie).to.not.exist();
  });

  it('calls onChange callback with uploaded image', async () => {
    const onChange = sinon.stub();
    const { getByLabelText } = render(
      <FailedCaptureAttemptsContextProvider
        maxCaptureAttemptsBeforeNativeCamera={3}
        maxSubmissionAttemptsBeforeNativeCamera={3}
        failedFingerprints={{ front: [], back: [] }}
      >
        <DocumentsStep
          value={{}}
          onChange={onChange}
          errors={[]}
          onError={() => undefined}
          registerField={() => undefined}
          unknownFieldErrors={[]}
          toPreviousStep={() => undefined}
        />
        ,
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
        <DocumentsStep
          value={{}}
          onChange={() => undefined}
          errors={[]}
          onError={() => undefined}
          registerField={() => undefined}
          unknownFieldErrors={[]}
          toPreviousStep={() => undefined}
        />
      </DeviceContext.Provider>,
    );

    expect(() => getByText('doc_auth.tips.document_capture_id_text4')).to.throw();

    getByText = render(
      <DocumentsStep
        value={{}}
        onChange={() => undefined}
        errors={[]}
        onError={() => undefined}
        registerField={() => undefined}
        unknownFieldErrors={[]}
        toPreviousStep={() => undefined}
      />,
    ).getByText;

    expect(() => getByText('doc_auth.tips.document_capture_id_text4')).not.to.throw();
  });

  it('renders the hybrid flow warning if the flow is hybrid', () => {
    const { getByText } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <UploadContextProvider flowPath="hybrid" endpoint="unused">
          <DocumentsStep
            value={{}}
            onChange={() => undefined}
            errors={[]}
            onError={() => undefined}
            registerField={() => undefined}
            unknownFieldErrors={[]}
            toPreviousStep={() => undefined}
          />
        </UploadContextProvider>
      </DeviceContext.Provider>,
    );
    const expectedText = t('doc_auth.hybrid_flow_warning.explanation_non_sp_html');

    expect(getByText(expectedText)).to.exist();
  });

  it('does not render the hybrid flow warning if the flow is standard (default)', () => {
    const { queryByText } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <UploadContextProvider flowPath="standard" endpoint="unused">
          <DocumentsStep
            value={{}}
            onChange={() => undefined}
            errors={[]}
            onError={() => undefined}
            registerField={() => undefined}
            unknownFieldErrors={[]}
            toPreviousStep={() => undefined}
          />
        </UploadContextProvider>
      </DeviceContext.Provider>,
    );
    const notExpectedText = t('doc_auth.hybrid_flow_warning.explanation_non_sp_html');

    expect(queryByText(notExpectedText)).to.not.exist();
  });

  it('renders only with front, back when isSelfieCaptureEnabled is true', () => {
    const { getByRole, getByLabelText } = render(
      <SelfieCaptureContext.Provider
        value={{
          isSelfieCaptureEnabled: true,
          isSelfieDesktopTestMode: false,
          showHelpInitially: true,
          immediatelyBeginCapture: true,
        }}
      >
        <DocumentsStep
          value={{}}
          onChange={() => undefined}
          errors={[]}
          onError={() => undefined}
          registerField={() => undefined}
          unknownFieldErrors={[]}
          toPreviousStep={() => undefined}
        />
      </SelfieCaptureContext.Provider>,
    );

    const front = getByLabelText('doc_auth.headings.document_capture_front');
    const back = getByLabelText('doc_auth.headings.document_capture_back');
    const pageHeader = getByRole('heading', {
      name: 'doc_auth.headings.document_capture',
      level: 1,
    });

    expect(front).to.be.ok();
    expect(back).to.be.ok();
    expect(pageHeader).to.be.ok();
  });
});
