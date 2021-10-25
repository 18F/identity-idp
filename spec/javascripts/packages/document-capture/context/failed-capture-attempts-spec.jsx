import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import FailedCaptureAttemptsContext, {
  Provider,
} from '@18f/identity-document-capture/context/failed-capture-attempts';

describe('document-capture/context/failed-capture-attempts', () => {
  it('has expected default properties', () => {
    const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext));

    expect(result.current).to.have.keys([
      'failedCaptureAttempts',
      'onFailedCaptureAttempt',
      'onResetFailedCaptureAttempts',
      'maxFailedAttemptsBeforeTips',
      'lastAttemptMetadata',
    ]);
    expect(result.current.failedCaptureAttempts).to.equal(0);
    expect(result.current.onFailedCaptureAttempt).to.be.a('function');
    expect(result.current.onResetFailedCaptureAttempts).to.be.a('function');
    expect(result.current.maxFailedAttemptsBeforeTips).to.be.a('number');
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
  });
});
