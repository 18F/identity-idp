import sinon from 'sinon';
import { render } from '@testing-library/react';
import { useLogCameraInfo } from '@18f/identity-document-capture/hooks/use-log-camera-info';
import { AnalyticsContextProvider } from '@18f/identity-document-capture/context/analytics';
import userEvent from '@testing-library/user-event';

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

// Give the global navigator object a mock camera with various functions so that the logging actually happens
const addMockCameraToNavigator = () => {
  Object.defineProperty(global.navigator, 'mediaDevices', {
    value: {
      getUserMedia: mockGetUserMedia,
      enumerateDevices: mockEnumerateDevices,
    },
    configurable: true,
    writable: true,
  });
};

describe('document-capture/hooks/use-log-camera-info', () => {
  addMockCameraToNavigator();

  it('logs camera info when isBackOfId and hasStartedCropping are both true', async () => {
    const trackEvent = sinon.stub();
    const [isBackOfId, hasStartedCropping] = [true, true];
    const { findByText } = render(
      <AnalyticsContextProvider trackEvent={trackEvent}>
        <MockComponent isBackOfId={isBackOfId} hasStartedCropping={hasStartedCropping} />
      </AnalyticsContextProvider>,
    );

    // This click is not triggering anything, it's the easiest way I found to make the test wait bit until the async
    // trackEvent can be called, I can't get 'waitFor' to work
    await userEvent.click(await findByText('mockcomponent'));
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

    // This click is not triggering anything, it's the easiest way I found to make the test wait bit until the async
    // trackEvent can be called, I can't get 'waitFor' to work
    await userEvent.click(await findByText('mockcomponent'));
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

    // This click is not triggering anything, it's the easiest way I found to make the test wait bit until the async
    // trackEvent can be called, I can't get 'waitFor' to work
    await userEvent.click(await findByText('mockcomponent'));
    expect(trackEvent).not.to.have.been.called();
  });

  it('logs a camera info error when getting media info fails', async () => {
    const trackEvent = sinon.stub();
    const [isBackOfId, hasStartedCropping] = [true, true];
    global.navigator.mediaDevices.getUserMedia = mockGetUserMediaThrowsError;
    const { findByText } = render(
      <AnalyticsContextProvider trackEvent={trackEvent}>
        <MockComponent isBackOfId={isBackOfId} hasStartedCropping={hasStartedCropping} />
      </AnalyticsContextProvider>,
    );

    // This click is not triggering anything, it's the easiest way I found to make the test wait bit until the async
    // trackEvent can be called, I can't get 'waitFor' to work
    await userEvent.click(await findByText('mockcomponent'));
    expect(trackEvent).to.have.been.calledWith('idv_camera_info_error');
  });
});
