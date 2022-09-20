import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import userEvent from '@testing-library/user-event';
import { DeviceContext, AnalyticsContext } from '@18f/identity-document-capture';
import { Provider as AcuantContextProvider } from '@18f/identity-document-capture/context/acuant';
import AcuantCapture from '@18f/identity-document-capture/components/acuant-capture';
import NativeCameraABTestContext, {
  Provider,
} from '@18f/identity-document-capture/context/native-camera-a-b-test';
import sinon from 'sinon';
import { render } from '../../../support/document-capture';

describe('document-capture/context/native-capture=a=b=test', () => {
  it('has expected default properties', () => {
    const { result } = renderHook(() => useContext(NativeCameraABTestContext));

    expect(result.current).to.have.keys(['nativeCameraABTestingEnabled', 'nativeCameraOnly']);
    expect(result.current.nativeCameraABTestingEnabled).to.equal(false);
    expect(result.current.nativeCameraOnly).to.equal(false);
  });
});

describe('NativeCameraABTest testing of nativeCameraOnly logic', () => {
  const nativeCameraABTestingEnabled = true;
  const nativeCameraOnly = true;
  it('Will return the given value of nativeCameraOnly', () => {
    const { result } = renderHook(() => useContext(NativeCameraABTestContext), {
      wrapper: ({ children }) => (
        <Provider
          nativeCameraABTestingEnabled={nativeCameraABTestingEnabled}
          nativeCameraOnly={nativeCameraOnly}
        >
          {children}
        </Provider>
      ),
    });
    expect(result.current).to.have.keys(['nativeCameraABTestingEnabled', 'nativeCameraOnly']);
    expect(result.current.nativeCameraABTestingEnabled).to.equal(true);
    expect(result.current.nativeCameraOnly).to.equal(true);
  });
});

describe('NativeCameraABTest logging tests', () => {
  context('user will skip sdk and only have the native camera option', function () {
    it('Calls analytics with native camera message when nativeCameraOnly is true', async function () {
      const trackEvent = sinon.spy();
      const acuantCaptureComponent = <AcuantCapture />;
      function TestComponent({ children }) {
        return (
          <AnalyticsContext.Provider value={{ trackEvent }}>
            <DeviceContext.Provider value={{ isMobile: true }}>
              <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
                <Provider nativeCameraABTestingEnabled nativeCameraOnly>
                  {acuantCaptureComponent}
                  {children}
                </Provider>
              </AcuantContextProvider>
            </DeviceContext.Provider>
          </AnalyticsContext.Provider>
        );
      }
      const result = render(<TestComponent />);
      const user = userEvent.setup();
      const fileInput = result.container.querySelector('input[type="file"]');
      expect(fileInput).to.exist();
      await user.click(fileInput);
      expect(trackEvent).to.have.been.calledWith('IdV: Native camera A/B Test', {
        native_camera_only: true,
      });
    });
  });
  context('user will be presented first with the sdk', function () {
    it('Calls analytics with native camera message when nativeCameraOnly is false', async function () {
      const trackEvent = sinon.spy();
      const acuantCaptureComponent = <AcuantCapture />;
      function TestComponent({ children }) {
        return (
          <AnalyticsContext.Provider value={{ trackEvent }}>
            <DeviceContext.Provider value={{ isMobile: true }}>
              <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
                <Provider nativeCameraABTestingEnabled nativeCameraOnly={false}>
                  {acuantCaptureComponent}
                  {children}
                </Provider>
              </AcuantContextProvider>
            </DeviceContext.Provider>
          </AnalyticsContext.Provider>
        );
      }
      const result = render(<TestComponent />);
      const user = userEvent.setup();
      const fileInput = result.container.querySelector('input[type="file"]');
      expect(fileInput).to.exist();
      await user.click(fileInput);
      expect(trackEvent).to.have.been.calledWith('IdV: Native camera A/B Test', {
        native_camera_only: false,
      });
    });
  });
  context('A/B Testing is disabled', function () {
    it('Does not call analytics with native camera message when nativeCameraABTestingEnabled is false', async function () {
      const trackEvent = sinon.spy();
      const acuantCaptureComponent = <AcuantCapture />;
      function TestComponent({ children }) {
        return (
          <AnalyticsContext.Provider value={{ trackEvent }}>
            <DeviceContext.Provider value={{ isMobile: true }}>
              <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
                <Provider nativeCameraABTestingEnabled={false} nativeCameraOnly>
                  {acuantCaptureComponent}
                  {children}
                </Provider>
              </AcuantContextProvider>
            </DeviceContext.Provider>
          </AnalyticsContext.Provider>
        );
      }
      const result = render(<TestComponent />);
      const user = userEvent.setup();
      const fileInput = result.container.querySelector('input[type="file"]');
      expect(fileInput).to.exist();
      await user.click(fileInput);
      expect(trackEvent).to.not.have.been.calledWith('IdV: Native camera A/B Test', {
        native_camera_only: true,
      });
    });
  });
});
