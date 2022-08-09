import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import { DeviceContext, AnalyticsContext } from '@18f/identity-document-capture';
import AcuantContext, {
  dirname,
  Provider as AcuantContextProvider,
  DEFAULT_ACCEPTABLE_GLARE_SCORE,
  DEFAULT_ACCEPTABLE_SHARPNESS_SCORE,
} from '@18f/identity-document-capture/context/acuant';

import FailedCaptureAttemptsContext, {
  Provider,
} from '@18f/identity-document-capture/context/failed-capture-attempts';
import sinon from 'sinon';

describe('document-capture/context/failed-capture-attempts', () => {
  it('has expected default properties', () => {
    const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext));

    expect(result.current).to.have.keys([
      'failedCaptureAttempts',
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
        wrapper: ({ children }) => <Provider maxFailedAttemptsBeforeTips={1}>{children}</Provider>,
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
    context('failed acuant camera attempts', function () {
      //let result;
      //let addPageAction;

      let addPageAction = sinon.spy();
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
        wrapper: ({ children }) => (
          <Provider maxAttemptsBeforeNativeCamera={3} maxFailedAttemptsBeforeTips={10}>
            <AnalyticsContext.Provider value={{ addPageAction }}>
              {children}
            </AnalyticsContext.Provider>
          </Provider>
        ),
      });
      // const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
      //   wrapper: ({ children }) => (
      //     <Provider maxAttemptsBeforeNativeCamera={2} maxFailedAttemptsBeforeTips={10}>
      //       {children}
      //     </Provider>
      //   ),
      // });
      result.current.onFailedCaptureAttempt({ isAssessedAsGlare: true, isAssessedAsBlurry: false });
      result.current.onFailedCaptureAttempt({ isAssessedAsGlare: true, isAssessedAsBlurry: false });
      result.current.onFailedCaptureAttempt({ isAssessedAsGlare: true, isAssessedAsBlurry: false });

      it('calls analytics with native camera message when failed attempts is greater than 2', function () {
        //expect(addPageAction).to.have.been.called();
        expect(addPageAction).to.have.been.calledWith(
          'IdV: Force native camera. Failed attempts: 3',
          `Failed attempts: ${result.current.failedCaptureAttempts}`,
        );
      });
    });
  });
});
