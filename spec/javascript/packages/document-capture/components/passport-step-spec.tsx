import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import { expect } from 'chai';
import { t } from '@18f/identity-i18n';
import {
  DeviceContext,
  UploadContextProvider,
  FailedCaptureAttemptsContextProvider,
} from '@18f/identity-document-capture';
import PassportStep from '@18f/identity-document-capture/components/passport-step';
import { render } from '../../../support/document-capture';
import { getFixtureFile } from '../../../support/file';

describe('document-capture/components/passport-step', () => {
  it('renders with only one input for passport by default', () => {
    const { getByLabelText } = render(
      <PassportStep
        value={{}}
        onChange={() => undefined}
        errors={[]}
        onError={() => undefined}
        registerField={() => undefined}
        unknownFieldErrors={[]}
        toPreviousStep={() => undefined}
      />,
    );

    const passport = getByLabelText('doc_auth.headings.document_capture_passport');

    expect(passport).to.be.ok();
  });

  it('calls onChange callback with uploaded image', async () => {
    const onChange = sinon.stub();
    const { getByLabelText } = render(
      <FailedCaptureAttemptsContextProvider
        maxCaptureAttemptsBeforeNativeCamera={3}
        maxSubmissionAttemptsBeforeNativeCamera={3}
        failedFingerprints={{ front: [], back: [] }}
      >
        <PassportStep
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
    const file = await getFixtureFile('doc_auth_images/passport.jpg');

    await Promise.all([
      new Promise((resolve) => onChange.callsFake(resolve)),
      userEvent.upload(getByLabelText('doc_auth.headings.document_capture_passport'), file),
    ]);
    expect(onChange).to.have.been.calledWith({
      passport: file,
      passport_image_metadata: sinon.match(/^\{.+\}$/),
    });
  });

  it('renders device-specific instructions', () => {
    let { getByText } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <PassportStep
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
      <PassportStep
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
        <UploadContextProvider flowPath="hybrid" endpoint="unused" idType="passport">
          <PassportStep
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
        <UploadContextProvider flowPath="standard" endpoint="unused" idType="passport">
          <PassportStep
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
});
