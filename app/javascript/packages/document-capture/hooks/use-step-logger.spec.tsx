import sinon from 'sinon';
import { renderHook } from '@testing-library/react-hooks';
import type { ComponentType } from 'react';
import useStepLogger, { LOGGED_STEPS } from './use-step-logger';
import AnalyticsContext from '../context/analytics';

describe('useStepLogger', () => {
  let trackEvent: sinon.SinonStub;
  let wrapper: ComponentType;

  beforeEach(() => {
    trackEvent = sinon.stub();
    wrapper = ({ children }) => (
      <AnalyticsContext.Provider value={{ trackEvent }}>{children}</AnalyticsContext.Provider>
    );
  });

  context('with step not included in allowlist', () => {
    it('does not log visit', () => {
      renderHook(() => useStepLogger('excluded'), { wrapper });

      expect(trackEvent).not.to.have.been.called();
    });

    it('does not log submission', () => {
      const { result } = renderHook(() => useStepLogger('excluded'), { wrapper });
      const { onStepSubmit } = result.current;

      onStepSubmit();

      expect(trackEvent).not.to.have.been.called();
    });
  });

  context('with step included in allowlist', () => {
    it('logs visit', () => {
      const stepName = LOGGED_STEPS[0];
      renderHook(() => useStepLogger(stepName), { wrapper });

      expect(trackEvent).to.have.been.calledWith(`IdV: ${stepName} visited`);
    });

    it('logs submission', () => {
      const stepName = LOGGED_STEPS[0];
      const { result } = renderHook(() => useStepLogger(stepName), { wrapper });
      const { onStepSubmit } = result.current;

      onStepSubmit(stepName);

      expect(trackEvent).to.have.been.calledWith(`IdV: ${stepName} submitted`);
    });
  });
});
