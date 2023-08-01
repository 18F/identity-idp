import sinon from 'sinon';
import { useSandbox } from '@18f/identity-test-helpers';
import '@18f/identity-modal/modal-element';
import './session-timeout-modal-element';
import type SessionTimeoutModalElement from './session-timeout-modal-element';

describe('SessionTimeoutModalElement', () => {
  const sandbox = useSandbox({ useFakeTimers: true });

  function createElement({
    warningOffsetInMilliseconds = 1000,
    timeout = new Date(),
  }: Partial<Pick<SessionTimeoutModalElement, 'warningOffsetInMilliseconds' | 'timeout'>>) {
    document.body.innerHTML = `
      <lg-session-timeout-modal
        warning-offset-in-seconds="${warningOffsetInMilliseconds / 1000}"
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
    context('modal not visible', () => {
      context('warning offset in the future', () => {
        it('schedules at warning offset', () => {
          sandbox.stub(window, 'setTimeout');

          const element = createElement({ warningOffsetInMilliseconds: 1000 });
          element.scheduleStatusCheck({ timeout: new Date(Date.now() + 1001) });

          expect(window.setTimeout).to.have.been.calledWith(sinon.match.func, 1);
        });
      });

      context('warning offset in the past', () => {
        it('immediately calls checkStatus', () => {
          sandbox.stub(window, 'setTimeout');

          const element = createElement({ warningOffsetInMilliseconds: 1000 });
          sandbox.stub(element, 'checkStatus');
          element.scheduleStatusCheck({ timeout: new Date(Date.now() + 999) });

          expect(window.setTimeout).not.to.have.been.called();
          expect(element.checkStatus).to.have.been.called();
        });
      });
    });

    context('modal visible', () => {
      context('timeout in the past', () => {
        it('does not schedule status check', () => {
          sandbox.stub(window, 'setTimeout');

          const element = createElement({ warningOffsetInMilliseconds: 1000 });
          sandbox.stub(element.modal, 'isVisible').get(() => true);
          element.scheduleStatusCheck({ timeout: new Date(Date.now() - 1) });

          expect(window.setTimeout).not.to.have.been.called();
        });
      });

      context('timeout in the future', () => {
        it('schedules status check for timeout', () => {
          sandbox.stub(window, 'setTimeout');

          const element = createElement({ warningOffsetInMilliseconds: 1000 });
          sandbox.stub(element.modal, 'isVisible').get(() => true);
          element.scheduleStatusCheck({ timeout: new Date(Date.now() + 1) });

          expect(window.setTimeout).to.have.been.calledWith(sinon.match.func, 1);
        });
      });
    });
  });
});
