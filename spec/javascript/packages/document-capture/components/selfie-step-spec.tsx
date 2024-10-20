import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import { expect } from 'chai';
import { FailedCaptureAttemptsContextProvider } from '@18f/identity-document-capture';
import SelfieStep from '@18f/identity-document-capture/components/selfie-step';
import { render } from '../../../support/document-capture';
import { getFixtureFile } from '../../../support/file';

describe('document-capture/components/selfie-step', () => {
  it('renders with only selfie input by default', () => {
    const { queryByLabelText } = render(
      <SelfieStep
        value={{}}
        onChange={() => undefined}
        errors={[]}
        onError={() => undefined}
        registerField={() => undefined}
        unknownFieldErrors={[]}
        toPreviousStep={() => undefined}
      />,
    );

    const front = queryByLabelText('doc_auth.headings.document_capture_front');
    const back = queryByLabelText('doc_auth.headings.document_capture_back');
    const selfie = queryByLabelText('doc_auth.headings.document_capture_selfie');

    expect(front).to.not.exist();
    expect(back).to.not.exist();
    expect(selfie).to.be.ok();
  });

  it('calls onChange callback with uploaded image', async () => {
    const onChange = sinon.stub();
    const { getByLabelText } = render(
      <FailedCaptureAttemptsContextProvider
        maxCaptureAttemptsBeforeNativeCamera={3}
        maxSubmissionAttemptsBeforeNativeCamera={3}
        failedFingerprints={{ front: [], back: [] }}
      >
        <SelfieStep
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
      userEvent.upload(getByLabelText('doc_auth.headings.document_capture_selfie'), file),
    ]);
    expect(onChange).to.have.been.calledWith({
      selfie: file,
      selfie_image_metadata: sinon.match(/^\{.+\}$/),
    });
  });
});
