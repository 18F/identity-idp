import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import userEvent from '@testing-library/user-event';
import { DeviceContext, AnalyticsContext } from '@18f/identity-document-capture';
import { Provider as AcuantContextProvider } from '@18f/identity-document-capture/context/acuant';
import AcuantCapture from '@18f/identity-document-capture/components/acuant-capture';
import AcuantSdkUpgradeABTestContext, {
  AcuantSdkUpgradeABTestContextProvider,
} from '@18f/identity-document-capture/context/acuant-sdk-upgrade-a-b-test';
import sinon from 'sinon';
import { render } from '../../../support/document-capture';

describe('document-capture/context/acuant-sdk-upgrade-a-b-test', () => {
  it('has expected default properties', () => {
    const { result } = renderHook(() => useContext(AcuantSdkUpgradeABTestContext));

    expect(result.current).to.have.keys(['acuantSdkUpgradeABTestingEnabled', 'useNewerSdk']);
    expect(result.current.acuantSdkUpgradeABTestingEnabled).to.equal(false);
    expect(result.current.useNewerSdk).to.equal(false);
  });
});

describe('AcuantSdkUpgradeABTest testing of useNewerSdk logic', () => {
  const acuantSdkUpgradeABTestingEnabled = true;
  const useNewerSdk = true;
  it('Will return the given value of useNewerSdk', () => {
    const { result } = renderHook(() => useContext(AcuantSdkUpgradeABTestContext), {
      wrapper: ({ children }) => (
        <AcuantSdkUpgradeABTestContextProvider
          value={{ acuantSdkUpgradeABTestingEnabled, useNewerSdk }}
        >
          {children}
        </AcuantSdkUpgradeABTestContextProvider>
      ),
    });
    expect(result.current).to.have.keys(['acuantSdkUpgradeABTestingEnabled', 'useNewerSdk']);
    expect(result.current.acuantSdkUpgradeABTestingEnabled).to.equal(true);
    expect(result.current.useNewerSdk).to.equal(true);
  });
});

describe('AcuantSdkUpgradeABTest logging tests', () => {
  context('user will use the older sdk', () => {
    it('Call analytics with the acuant sdk ab test message with correct values', () => {
      const trackEvent = sinon.spy();
      const acuantCaptureComponent = <AcuantCapture />;
      function TestComponent({ children }) {
        return (
          <AnalyticsContext.Provider value={{ trackEvent }}>
            <DeviceContext.Provider value={{ isMobile: true }}>
              <AcuantSdkUpgradeABTestContextProvider
                value={{ acuantSdkUpgradeABTestingEnabled: true, useNewerSdk: false }}
              >
                <AcuantContextProvider>
                  {acuantCaptureComponent}
                  {children}
                </AcuantContextProvider>
              </AcuantSdkUpgradeABTestContextProvider>
            </DeviceContext.Provider>
          </AnalyticsContext.Provider>
        );
      }
      const result = render(<TestComponent />);
      expect(trackEvent).to.have.been.calledWith('IdV: Acuant SDK Upgrade A/B Test', {
        use_newer_sdk: false,
        version: '11.7.0',
      });
    });
  });
  context('user will use the newer sdk', () => {
    it('Call analytics with the acuant sdk ab test message with correct values', () => {
      const trackEvent = sinon.spy();
      const acuantCaptureComponent = <AcuantCapture />;
      function TestComponent({ children }) {
        return (
          <AnalyticsContext.Provider value={{ trackEvent }}>
            <DeviceContext.Provider value={{ isMobile: true }}>
              <AcuantSdkUpgradeABTestContextProvider
                value={{ acuantSdkUpgradeABTestingEnabled: true, useNewerSdk: true }}
              >
                <AcuantContextProvider>
                  {acuantCaptureComponent}
                  {children}
                </AcuantContextProvider>
              </AcuantSdkUpgradeABTestContextProvider>
            </DeviceContext.Provider>
          </AnalyticsContext.Provider>
        );
      }
      const result = render(<TestComponent />);
      expect(trackEvent).to.have.been.calledWith('IdV: Acuant SDK Upgrade A/B Test', {
        use_newer_sdk: true,
        version: '11.7.1',
      });
    });
  });
  context('AB testing is completely disabled', () => {
    it('Does not call analytics at all for the a/b test event', () => {
      const trackEvent = sinon.spy();
      const acuantCaptureComponent = <AcuantCapture />;
      function TestComponent({ children }) {
        return (
          <AnalyticsContext.Provider value={{ trackEvent }}>
            <DeviceContext.Provider value={{ isMobile: true }}>
              <AcuantSdkUpgradeABTestContextProvider
                value={{ acuantSdkUpgradeABTestingEnabled: false, useNewerSdk: false }}
              >
                <AcuantContextProvider>
                  {acuantCaptureComponent}
                  {children}
                </AcuantContextProvider>
              </AcuantSdkUpgradeABTestContextProvider>
            </DeviceContext.Provider>
          </AnalyticsContext.Provider>
        );
      }
      const result = render(<TestComponent />);
      expect(trackEvent).to.not.have.been.calledWith('IdV: Acuant SDK Upgrade A/B Test');
    });
  });
});
