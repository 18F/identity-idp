import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import { expect } from 'chai';
import { FailedCaptureAttemptsContextProvider } from '@18f/identity-document-capture';
import SelfieCaptureContext from '@18f/identity-document-capture/context/selfie-capture';
import SelfieStep from '@18f/identity-document-capture/components/selfie-step';
import { render } from '../../../support/document-capture';
import { getFixtureFile } from '../../../support/file';

describe('document-capture/components/selfie-step', () => {
  let getByLabelText;
  let queryByLabelText;

  context('when initially shown', () => {
    beforeEach(() => {
      ({ queryByLabelText } = render(
        <SelfieStep
          value={{}}
          onChange={() => undefined}
          errors={[]}
          onError={() => undefined}
          registerField={() => undefined}
          unknownFieldErrors={[]}
          toPreviousStep={() => undefined}
        />,
      ));
    });
  });

  context('when show help is turned off ', () => {
    beforeEach(() => {
      ({ queryByLabelText } = render(
        <SelfieCaptureContext.Provider
          value={{
            isSelfieCaptureEnabled: false,
            isUploadEnabled: false,
            isSelfieDesktopTestMode: false,
            showHelpInitially: false,
          }}
        >
          <SelfieStep
            value={{}}
            onChange={() => undefined}
            errors={[]}
            onError={() => undefined}
            registerField={() => undefined}
            unknownFieldErrors={[]}
            toPreviousStep={() => undefined}
          />
          ,
        </SelfieCaptureContext.Provider>,
      ));
    });

    it('renders with only selfie input', () => {
      const front = queryByLabelText('doc_auth.headings.document_capture_front');
      const back = queryByLabelText('doc_auth.headings.document_capture_back');
      const selfie = queryByLabelText('doc_auth.headings.document_capture_selfie');

      expect(front).to.not.exist();
      expect(back).to.not.exist();
      expect(selfie).to.be.ok();
    });
  });

  it('calls onChange callback with uploaded image', async () => {
    const onChange = sinon.stub();
    ({ getByLabelText } = render(
      <FailedCaptureAttemptsContextProvider
        maxCaptureAttemptsBeforeNativeCamera={3}
        maxSubmissionAttemptsBeforeNativeCamera={3}
        failedFingerprints={{ front: [], back: [], passport: [] }}
      >
        <SelfieCaptureContext.Provider
          value={{
            isSelfieCaptureEnabled: false,
            isUploadEnabled: true,
            isSelfieDesktopTestMode: false,
            showHelpInitially: false,
          }}
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
        </SelfieCaptureContext.Provider>
        ,
      </FailedCaptureAttemptsContextProvider>,
    ));
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
