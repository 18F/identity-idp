import sinon from 'sinon';
import { render } from '@testing-library/react';
import { useLogCameraInfo } from '@18f/identity-document-capture/hooks/use-log-camera-info';
import { AnalyticsContextProvider } from '@18f/identity-document-capture/context/analytics';
import { useDefineProperty } from '@18f/identity-test-helpers';
import { waitFor } from '@testing-library/dom';

interface MockComponentProps {
  isBackOfId: boolean;
  hasStartedCropping: boolean;
}

function MockComponent({ isBackOfId, hasStartedCropping }: MockComponentProps) {
  useLogCameraInfo({ isBackOfId, hasStartedCropping });
  return <div>mockcomponent</div>;
}

const mockTrack = {
  label: 'mockTrackLabel',
  getSettings: () => ({
    frameRate: 60,
    height: 3000,
    width: 3000,
  }),
};

const mockDeviceId = 'mockDeviceId';
const mockGetVideoTracks = () => [mockTrack];
const mockDevice = {
  kind: 'videoinput',
  deviceId: mockDeviceId,
};

const mockGetUserMediaThrowsError = () => {
  throw new Error('camera logging failed');
};
const mockGetUserMedia = () =>
  new Promise((resolve) => resolve({ getVideoTracks: mockGetVideoTracks }));
const mockEnumerateDevices = () => new Promise((resolve) => resolve([mockDevice]));

describe('document-capture/hooks/use-log-camera-info', () => {
  const defineProperty = useDefineProperty();
  beforeEach(() => {
    defineProperty(global.navigator, 'mediaDevices', {
      value: {
        getUserMedia: mockGetUserMedia,
        enumerateDevices: mockEnumerateDevices,
      },
      configurable: true,
      writable: true,
    });
  });

  it('logs camera info when isBackOfId and hasStartedCropping are both true', async () => {
    const trackEvent = sinon.stub();
    const [isBackOfId, hasStartedCropping] = [true, true];
    const { findByText } = render(
      <AnalyticsContextProvider trackEvent={trackEvent}>
        <MockComponent isBackOfId={isBackOfId} hasStartedCropping={hasStartedCropping} />
      </AnalyticsContextProvider>,
    );

    await waitFor(() => findByText('mockcomponent'));
    expect(trackEvent).to.have.been.calledWith('idv_camera_info_logged');
  });

  it('doesnt log camera info when isBackOfId is false', async () => {
    const trackEvent = sinon.stub();
    const [isBackOfId, hasStartedCropping] = [false, true];
    const { findByText } = render(
      <AnalyticsContextProvider trackEvent={trackEvent}>
        <MockComponent isBackOfId={isBackOfId} hasStartedCropping={hasStartedCropping} />
      </AnalyticsContextProvider>,
    );

    await waitFor(() => findByText('mockcomponent'));
    expect(trackEvent).not.to.have.been.called();
  });

  it('doesnt log camera info when hasStartedCropping is false', async () => {
    const trackEvent = sinon.stub();
    const [isBackOfId, hasStartedCropping] = [true, false];
    const { findByText } = render(
      <AnalyticsContextProvider trackEvent={trackEvent}>
        <MockComponent isBackOfId={isBackOfId} hasStartedCropping={hasStartedCropping} />
      </AnalyticsContextProvider>,
    );

    await waitFor(() => findByText('mockcomponent'));
    expect(trackEvent).not.to.have.been.called();
  });

  it('logs a camera info error when getting media info fails', async () => {
    const trackEvent = sinon.stub();
    const [isBackOfId, hasStartedCropping] = [true, true];
    // Override a previously mocked window function to always throw an error
    global.navigator.mediaDevices.getUserMedia = mockGetUserMediaThrowsError;
    const { findByText } = render(
      <AnalyticsContextProvider trackEvent={trackEvent}>
        <MockComponent isBackOfId={isBackOfId} hasStartedCropping={hasStartedCropping} />
      </AnalyticsContextProvider>,
    );

    await waitFor(() => findByText('mockcomponent'));
    expect(trackEvent).to.have.been.calledWith('idv_camera_info_error');
  });
});
