import sinon from 'sinon';
import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import type { ComponentType } from 'react';
import AnalyticsContext, { AnalyticsContextProvider, LOGGED_STEPS } from './analytics';

describe('AnalyticsContextProvider', () => {
  let trackEvent: sinon.SinonStub;
  let wrapper: ComponentType;
  beforeEach(() => {
    trackEvent = sinon.stub();
    wrapper = ({ children }) => (
      <AnalyticsContextProvider trackEvent={trackEvent}>{children}</AnalyticsContextProvider>
    );
  });

  it('provides default context values', () => {
    const { result } = renderHook(() => useContext(AnalyticsContext), { wrapper });

    expect(result.current).to.have.all.keys([
      'trackEvent',
      'trackSubmitEvent',
      'trackVisitEvent',
      'submitEventMetadata',
      'setSubmitEventMetadata',
    ]);
  });

  it('calls trackEvent with visit event', () => {
    const stepName = LOGGED_STEPS[0];
    const { result } = renderHook(() => useContext(AnalyticsContext), { wrapper });

    result.current.trackVisitEvent(stepName);

    expect(trackEvent).to.have.been.calledWith(`IdV: ${stepName} visited`);
  });

  it('calls trackEvent with submit event', () => {
    const stepName = LOGGED_STEPS[0];
    const { result } = renderHook(() => useContext(AnalyticsContext), { wrapper });

    result.current.trackSubmitEvent(stepName);

    expect(trackEvent).to.have.been.calledWith(`IdV: ${stepName} submitted`, {});
  });

  it('includes metadata in the next submit event', () => {
    const stepName = LOGGED_STEPS[0];
    const { result } = renderHook(() => useContext(AnalyticsContext), { wrapper });

    result.current.setSubmitEventMetadata({ ok: true });
    result.current.trackSubmitEvent(stepName);

    expect(trackEvent).to.have.been.calledWith(`IdV: ${stepName} submitted`, { ok: true });
  });

  it('does not include metadata in subsequent submit events', () => {
    const firstStepName = LOGGED_STEPS[0];
    const secondStepName = LOGGED_STEPS[1];
    const { result } = renderHook(() => useContext(AnalyticsContext), { wrapper });

    result.current.setSubmitEventMetadata({ ok: true });
    result.current.trackSubmitEvent(firstStepName);
    result.current.trackSubmitEvent(secondStepName);

    expect(trackEvent).to.have.been.calledWith(`IdV: ${firstStepName} submitted`, { ok: true });
    expect(trackEvent).to.have.been.calledWith(`IdV: ${secondStepName} submitted`, {});
  });
});
