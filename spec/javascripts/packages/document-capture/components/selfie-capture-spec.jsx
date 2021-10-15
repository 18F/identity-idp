import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
import { cleanup } from '@testing-library/react';
import { I18nContext } from '@18f/identity-react-i18n';
import SelfieCapture from '@18f/identity-document-capture/components/selfie-capture';
import { render } from '../../../support/document-capture';
import { useSandbox } from '../../../support/sinon';
import { getFixtureFile } from '../../../support/file';

describe('document-capture/components/selfie-capture', () => {
  // Since DOM globals are stubbed with sandbox, ensure that cleanup is the first task, as otherwise
  // it will attempt to reference globals which had already been cleaned up and are undefined.
  afterEach(cleanup);

  const sandbox = useSandbox();

  const wrapper = ({ children }) => (
    <I18nContext.Provider
      value={{
        'doc_auth.instructions.document_capture_selfie_consent_action':
          '<lg-underline>Allow access</lg-underline>',
      }}
    >
      {children}
    </I18nContext.Provider>
  );

  const track = { stop: sinon.stub() };
  let value;
  before(async () => {
    value = await getFixtureFile('doc_auth_images/selfie.jpg');
  });

  let originalMediaDevices;
  let originalMediaStream;
  let originalPermissions;
  beforeEach(() => {
    originalMediaDevices = navigator.mediaDevices;
    originalPermissions = navigator.permissions;

    function MediaStream() {}
    MediaStream.prototype = { play() {}, getTracks() {} };
    sandbox.stub(MediaStream.prototype, 'play');
    sandbox.stub(MediaStream.prototype, 'getTracks').returns([track]);

    sandbox.stub(window.HTMLMediaElement.prototype, 'play');

    navigator.mediaDevices = {
      getUserMedia: () => Promise.resolve(new MediaStream()),
    };

    originalMediaStream = window.MediaStream;
    window.MediaStream = MediaStream;

    track.stop.resetHistory();
  });

  afterEach(() => {
    if (originalMediaDevices === undefined) {
      delete navigator.mediaDevices;
    } else {
      navigator.mediaDevices = originalMediaDevices;
    }

    if (originalMediaStream === undefined) {
      delete window.MediaStream;
    } else {
      window.MediaStream = originalMediaStream;
    }

    if (originalPermissions === undefined) {
      delete navigator.permissions;
    } else {
      navigator.permissions = originalPermissions;
    }
  });

  it('renders a consent prompt', () => {
    const { getByText } = render(<SelfieCapture />);

    expect(getByText('doc_auth.instructions.document_capture_selfie_consent_banner')).to.be.ok();
  });

  it('renders video element that auto-plays if previous consent granted', async () => {
    navigator.permissions = {
      query: sinon
        .stub()
        .withArgs({ name: 'camera' })
        .returns(Promise.resolve({ state: 'granted' })),
    };
    const { getByLabelText, findByLabelText } = render(<SelfieCapture />);

    await findByLabelText('doc_auth.buttons.take_picture');
    const video = getByLabelText('doc_auth.headings.document_capture_selfie');
    expect(video.srcObject).to.be.instanceOf(window.MediaStream);
  });

  it('renders video element that plays after consent granted', async () => {
    const { getByText, getByLabelText, findByLabelText } = render(<SelfieCapture />, { wrapper });
    userEvent.click(getByText('Allow access'));

    await findByLabelText('doc_auth.buttons.take_picture');
    const video = getByLabelText('doc_auth.headings.document_capture_selfie');
    expect(video.srcObject).to.be.instanceOf(window.MediaStream);
  });

  it('stops capture when unmounted', async () => {
    const { getByText, findByLabelText, unmount } = render(<SelfieCapture />, { wrapper });
    userEvent.click(getByText('Allow access'));

    await findByLabelText('doc_auth.buttons.take_picture');
    unmount();
    expect(track.stop.calledOnce).to.be.true();
  });

  it('renders error state if previous consent denied', async () => {
    navigator.permissions = {
      query: sinon
        .stub()
        .withArgs({ name: 'camera' })
        .returns(Promise.resolve({ state: 'denied' })),
    };
    const { findByText } = render(<SelfieCapture />);

    await findByText('doc_auth.instructions.document_capture_selfie_consent_blocked');
  });

  it('renders error state if devices access restricted', async () => {
    const error = new Error();
    error.name = 'NotAllowedError';
    navigator.mediaDevices.getUserMedia = () => Promise.reject(error);
    const { getByText, findByText } = render(<SelfieCapture />, { wrapper });
    userEvent.click(getByText('Allow access'));

    await findByText('doc_auth.instructions.document_capture_selfie_consent_blocked');
  });

  it('renders updated state after retaking photo', async () => {
    const { rerender, findByText } = render(<SelfieCapture value={value} />);
    rerender(<SelfieCapture />);
    rerender(<SelfieCapture value={value} />);

    await findByText('doc_auth.info.image_updated');
  });

  it('stops capture after rerendered with value', async () => {
    const { findByLabelText, getByText, rerender } = render(<SelfieCapture />, { wrapper });

    userEvent.click(getByText('Allow access'));
    await findByLabelText('doc_auth.buttons.take_picture');
    rerender(<SelfieCapture value={value} />);
    expect(track.stop.calledOnce).to.be.true();
  });

  it('renders value preview', async () => {
    const { findByText } = render(<SelfieCapture value={value} />);

    await findByText('doc_auth.buttons.take_picture_retry');
  });

  it('accepts additional className to apply to container element', () => {
    const { container } = render(<SelfieCapture className="example" />);

    expect(container.querySelector('.selfie-capture.example')).to.be.ok();
  });
});
