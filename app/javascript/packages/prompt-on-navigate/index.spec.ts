import { useSandbox } from '@18f/identity-test-helpers';
import * as analytics from '@18f/identity-analytics';
import { PROMPT_EVENT, STILL_ON_PAGE_EVENT, promptOnNavigate } from '.';

describe('promptOnNavigate', () => {
  const sandbox = useSandbox({ useFakeTimers: true });

  it('prompts on navigate', () => {
    promptOnNavigate();

    const event = new window.Event('beforeunload', { cancelable: true, bubbles: false });
    window.dispatchEvent(event);

    expect(event.defaultPrevented).to.be.true();
    expect(event.returnValue).to.be.false();
  });

  it('logs an event', () => {
    const trackEvent = sandbox.spy(analytics, 'trackEvent');

    promptOnNavigate();

    const event = new window.Event('beforeunload', { cancelable: true, bubbles: false });
    window.dispatchEvent(event);

    expect(trackEvent).to.have.been.calledOnceWith(PROMPT_EVENT);
  });

  it('logs a second event when the user stays on the page for 5s', () => {
    const trackEvent = sandbox.spy(analytics, 'trackEvent');

    promptOnNavigate();

    const event = new window.Event('beforeunload', { cancelable: true, bubbles: false });

    window.dispatchEvent(event);

    expect(trackEvent).to.have.been.calledOnceWith(PROMPT_EVENT, { path: '/' });
    trackEvent.resetHistory();

    sandbox.clock.tick(2000);
    expect(trackEvent).not.to.have.been.called();

    sandbox.clock.tick(3000);
    expect(trackEvent).to.have.been.calledWith(STILL_ON_PAGE_EVENT, {
      path: '/',
      seconds: 5,
    });
  });

  it('logs a third event when the user stays on the page for 15s', () => {
    const trackEvent = sandbox.spy(analytics, 'trackEvent');

    promptOnNavigate();

    const event = new window.Event('beforeunload', { cancelable: true, bubbles: false });

    window.dispatchEvent(event);

    expect(trackEvent).to.have.been.calledOnceWith(PROMPT_EVENT, { path: '/' });
    trackEvent.resetHistory();

    sandbox.clock.tick(5000);
    expect(trackEvent).to.have.been.called();
    trackEvent.resetHistory();

    sandbox.clock.tick(10000);
    expect(trackEvent).to.have.been.calledWith(STILL_ON_PAGE_EVENT, {
      path: '/',
      seconds: 15,
    });
  });

  it('logs a fourth event when the user stays on the page for 30s', () => {
    const trackEvent = sandbox.spy(analytics, 'trackEvent');

    promptOnNavigate();

    const event = new window.Event('beforeunload', { cancelable: true, bubbles: false });

    window.dispatchEvent(event);

    expect(trackEvent).to.have.been.called();
    trackEvent.resetHistory();

    sandbox.clock.tick(5000);
    expect(trackEvent).to.have.been.called();
    trackEvent.resetHistory();

    sandbox.clock.tick(10000);
    expect(trackEvent).to.have.been.called();
    trackEvent.resetHistory();

    sandbox.clock.tick(15000);
    expect(trackEvent).to.have.been.calledWith(STILL_ON_PAGE_EVENT, {
      path: '/',
      seconds: 30,
    });
  });

  it('cleans up after itself', () => {
    window.onbeforeunload = null;

    const cleanup = promptOnNavigate();

    expect(window.onbeforeunload).not.to.be.null();

    cleanup();

    expect(window.onbeforeunload).to.be.null();
  });

  it("does not clean up someone else's handler", () => {
    const clean = promptOnNavigate();
    const custom = () => {};
    window.onbeforeunload = custom;
    clean();
    expect(window.onbeforeunload).to.eql(custom);
  });

  it('does not fire second analytics event after cleanup', () => {
    const trackEvent = sandbox.spy(analytics, 'trackEvent');

    const cleanup = promptOnNavigate();

    const event = new window.Event('beforeunload', { cancelable: true, bubbles: false });
    window.dispatchEvent(event);

    expect(trackEvent).to.have.been.calledOnceWith(PROMPT_EVENT);
    trackEvent.resetHistory();

    sandbox.clock.tick(2000);
    expect(trackEvent).not.to.have.been.called();

    cleanup();

    sandbox.clock.tick(10000);
    expect(trackEvent).not.to.have.been.called();
  });

  it('does not throw if you call cleanup a bunch', () => {
    const cleanup = promptOnNavigate();
    for (let i = 0; i < 10; i++) {
      cleanup();
    }
  });
});
