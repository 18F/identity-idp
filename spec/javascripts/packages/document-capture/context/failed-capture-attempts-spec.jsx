import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import userEvent from '@testing-library/user-event';
import { DeviceContext, AnalyticsContext } from '@18f/identity-document-capture';
import { Provider as AcuantContextProvider } from '@18f/identity-document-capture/context/acuant';
import AcuantCapture from '@18f/identity-document-capture/components/acuant-capture';
import FailedCaptureAttemptsContext, {
  Provider,
} from '@18f/identity-document-capture/context/failed-capture-attempts';
import sinon from 'sinon';
import { render } from '../../../support/document-capture';

describe('document-capture/context/failed-capture-attempts', () => {
  it('has expected default properties', () => {
    const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext));

    expect(result.current).to.have.keys([
      'failedCaptureAttempts',
      'forceNativeCamera',
      'onFailedCaptureAttempt',
      'onResetFailedCaptureAttempts',
      'maxFailedAttemptsBeforeTips',
      'maxAttemptsBeforeNativeCamera',
      'lastAttemptMetadata',
    ]);
    expect(result.current.failedCaptureAttempts).to.equal(0);
    expect(result.current.onFailedCaptureAttempt).to.be.a('function');
    expect(result.current.onResetFailedCaptureAttempts).to.be.a('function');
    expect(result.current.maxFailedAttemptsBeforeTips).to.be.a('number');
    expect(result.current.maxAttemptsBeforeNativeCamera).to.be.a('number');
    expect(result.current.lastAttemptMetadata).to.be.an('object');
  });

  describe('Provider', () => {
    it('sets increments on onFailedCaptureAttempt', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
        wrapper: ({ children }) => (
          <Provider maxAttemptsBeforeNativeCamera={2} maxFailedAttemptsBeforeTips={10}>
            {children}
          </Provider>
        ),
      });

      result.current.onFailedCaptureAttempt({ isAssessedAsGlare: true, isAssessedAsBlurry: false });

      expect(result.current.failedCaptureAttempts).to.equal(1);
    });

    it('sets metadata from onFailedCaptureAttempt', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
        wrapper: ({ children }) => <Provider maxFailedAttemptsBeforeTips={1}>{children}</Provider>,
      });

      const metadata = { isAssessedAsGlare: true, isAssessedAsBlurry: false };

      result.current.onFailedCaptureAttempt(metadata);

      expect(result.current.lastAttemptMetadata).to.deep.equal(metadata);
    });
  });
});

describe('FailedCaptureAttemptsContext testing of forceNativeCamera logic', () => {
  it('Updating to a number of failed captures less than maxAttemptsBeforeNativeCamera will keep forceNativeCamera as false', () => {
    const { result, rerender } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
      wrapper: ({ children }) => (
        <Provider maxAttemptsBeforeNativeCamera={2} maxFailedAttemptsBeforeTips={10}>
          {children}
        </Provider>
      ),
    });
    result.current.onFailedCaptureAttempt({
      isAssessedAsGlare: true,
      isAssessedAsBlurry: false,
    });
    rerender(true);
    expect(result.current.failedCaptureAttempts).to.equal(1);
    expect(result.current.forceNativeCamera).to.equal(false);
  });
  it('Updating failed captures to a number gte the maxAttemptsBeforeNativeCamera will set forceNativeCamera to true', () => {
    const { result, rerender } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
      wrapper: ({ children }) => (
        <Provider maxAttemptsBeforeNativeCamera={2} maxFailedAttemptsBeforeTips={10}>
          {children}
        </Provider>
      ),
    });
    result.current.onFailedCaptureAttempt({
      isAssessedAsGlare: true,
      isAssessedAsBlurry: false,
    });
    rerender(true);
    expect(result.current.forceNativeCamera).to.equal(false);
    result.current.onFailedCaptureAttempt({
      isAssessedAsGlare: true,
      isAssessedAsBlurry: false,
    });
    rerender(true);
    expect(result.current.forceNativeCamera).to.equal(true);
    result.current.onFailedCaptureAttempt({
      isAssessedAsGlare: true,
      isAssessedAsBlurry: false,
    });
    rerender({});
    expect(result.current.failedCaptureAttempts).to.equal(3);
    expect(result.current.forceNativeCamera).to.equal(true);
  });
});

describe('maxAttemptsBeforeNativeCamera logging tests', () => {
  context('failed acuant camera attempts', function () {
    /**
     * NOTE: We have to force maxAttemptsBeforeLogin to be 0 here
     * in order to test this interactively. This is because the react
     * testing library does not provide consistent ways to test using both
     * a component's elements (for triggering clicks) and a component's
     * subscribed context changes. You can use either render or renderHook,
     * but not both.
     */
    it('calls analytics with native camera message when failed attempts is greater than or equal to 0', async function () {
      const addPageAction = sinon.spy();
      const acuantCaptureComponent = <AcuantCapture name="example" />;
      function TestComponent({ children }) {
        return (
          <AnalyticsContext.Provider value={{ addPageAction }}>
            <DeviceContext.Provider value={{ isMobile: true }}>
              <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
                <Provider maxAttemptsBeforeNativeCamera={0} maxFailedAttemptsBeforeTips={10}>
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
      expect(addPageAction).to.have.been.called();
      expect(addPageAction).to.have.been.calledWith(
        'IdV: Native camera forced after failed attempts',
        { field: 'example', failed_attempts: 0 },
      );
    });

    it('Does not call analytics with native camera message when failed attempts less than 2', async function () {
      const addPageAction = sinon.spy();
      const acuantCaptureComponent = <AcuantCapture />;
      function TestComponent({ children }) {
        return (
          <AnalyticsContext.Provider value={{ addPageAction }}>
            <DeviceContext.Provider value={{ isMobile: true }}>
              <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
                <Provider maxAttemptsBeforeNativeCamera={2} maxFailedAttemptsBeforeTips={10}>
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
      expect(addPageAction).to.not.have.been.calledWith(
        'IdV: Native camera forced after failed attempts',
      );
    });
  });
});
