import React from 'react';
import sinon from 'sinon';
import { cleanup } from '@testing-library/react';
import SelfieCapture from '@18f/identity-document-capture/components/selfie-capture';
import render from '../../../support/render';
import { useSandbox } from '../../../support/sinon';

describe('document-capture/components/selfie-capture', () => {
  // Since DOM globals are stubbed with sandbox, ensure that cleanup is the first task, as otherwise
  // it will attempt to reference globals which had already been cleaned up and are undefined.
  afterEach(cleanup);

  const sandbox = useSandbox();

  const track = { stop: sinon.stub() };
  const value = new window.File([], 'image.png', { type: 'image/png' });

  let originalMediaDevices;
  let originalMediaStream;
  beforeEach(() => {
    originalMediaDevices = navigator.mediaDevices;

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
  });

  it('renders video element that auto-plays when devices retrieved', async () => {
    const { getByLabelText, findByLabelText } = render(<SelfieCapture />);

    await findByLabelText('doc_auth.buttons.take_picture');
    const video = getByLabelText('doc_auth.headings.document_capture_selfie');
    expect(video.srcObject).to.be.instanceOf(window.MediaStream);
  });

  it('stops capture when unmounted', async () => {
    const { findByLabelText, unmount } = render(<SelfieCapture />);

    await findByLabelText('doc_auth.buttons.take_picture');
    unmount();
    expect(track.stop.calledOnce).to.be.true();
  });

  it('renders error state if devices access restricted', async () => {
    const error = new Error();
    error.name = 'NotAllowedError';
    navigator.mediaDevices.getUserMedia = () => Promise.reject(error);
    const { findByText } = render(<SelfieCapture />);

    await findByText('doc_auth.instructions.document_capture_selfie_consent_blocked');
  });

  it('stops capture after rerendered with value', async () => {
    const { findByLabelText, rerender } = render(<SelfieCapture />);

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
