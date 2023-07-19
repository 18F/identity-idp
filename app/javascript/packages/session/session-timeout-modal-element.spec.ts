import sinon from 'sinon';
import { useSandbox } from '@18f/identity-test-helpers';
import './session-timeout-modal-element';
import type SessionTimeoutModalElement from './session-timeout-modal-element';

describe('SessionTimeoutModalElement', () => {
  const sandbox = useSandbox({ useFakeTimers: true });

  function createElement({
    warningOffset = 1000,
    timeout = new Date(),
  }: Partial<Pick<SessionTimeoutModalElement, 'warningOffset' | 'timeout'>>) {
    document.body.innerHTML = `
      <lg-session-timeout-modal
        warning-offset-in-seconds="${warningOffset / 1000}"
        timeout="${timeout.toISOString()}"
      >
        <lg-modal>
          <button class="lg-session-timeout-modal__keep-alive-button">
            Stay Signed In
          </button>
          <button class="lg-session-timeout-modal__sign-out-button">
            Sign Out
          </button>
        </lg-modal>
      </lg-session-timeout-modal>
    `;

    return document.querySelector('lg-session-timeout-modal')!;
  }

  describe('#scheduleStatusCheck', () => {
    context('timeout after warning offset', () => {
      it('schedules at warning offset', () => {
        sandbox.stub(window, 'setTimeout');

        const element = createElement({ warningOffset: 1000 });
        element.scheduleStatusCheck({ timeout: new Date(Date.now() + 1001) });

        expect(window.setTimeout).to.have.been.calledWith(sinon.match.func, 1);
      });
    });

    context('timeout before warning offset', () => {
      it('schedules at timeout', () => {
        sandbox.stub(window, 'setTimeout');

        const element = createElement({ warningOffset: 1000 });
        element.scheduleStatusCheck({ timeout: new Date(Date.now() + 999) });

        expect(window.setTimeout).to.have.been.calledWith(sinon.match.func, 999);
      });
    });

    context('timeout before now', () => {
      it('does not schedule', () => {
        sandbox.stub(window, 'setTimeout');

        const element = createElement({ warningOffset: 1000 });
        element.scheduleStatusCheck({ timeout: new Date(Date.now() - 1) });

        expect(window.setTimeout).not.to.have.been.called();
      });
    });
  });
});
