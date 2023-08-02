import sinon from 'sinon';
import quibble from 'quibble';
import { screen, waitFor } from '@testing-library/dom';
import baseUserEvent from '@testing-library/user-event';
import { useSandbox } from '@18f/identity-test-helpers';
import '@18f/identity-modal/modal-element';
import type ModalElement from '@18f/identity-modal/modal-element';
import type SessionTimeoutModalElement from './session-timeout-modal-element';

describe('SessionTimeoutModalElement', () => {
  const sandbox = useSandbox({ useFakeTimers: true });
  const requestSessionStatus = sinon.stub();
  const extendSession = sinon.stub();
  const userEvent = baseUserEvent.setup({ advanceTimers: sandbox.clock.tick });

  before(async () => {
    quibble('./requests', { requestSessionStatus, extendSession });
    await import('./session-timeout-modal-element');
  });

  beforeEach(() => {
    requestSessionStatus.reset();
    extendSession.reset();
  });

  after(() => {
    quibble.reset();
  });

  function createElement({
    warningOffsetInMilliseconds = 1000,
    timeout,
  }: Partial<Pick<SessionTimeoutModalElement, 'warningOffsetInMilliseconds' | 'timeout'>>) {
    document.body.innerHTML = `
      <lg-session-timeout-modal
        warning-offset-in-seconds="${warningOffsetInMilliseconds / 1000}"
        ${timeout ? `timeout="${timeout.toISOString()}"` : ''}
      >
        <lg-modal role="dialog">
          <button type="button" class="lg-session-timeout-modal__keep-alive-button">
            Stay Signed In
          </button>
          <button type="button" class="lg-session-timeout-modal__sign-out-button">
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
          element.timeout = new Date(Date.now() + 1001);

          expect(window.setTimeout).to.have.been.calledWith(sinon.match.func, 1);
        });
      });

      context('warning offset in the past', () => {
        it('immediately calls checkStatus', () => {
          sandbox.stub(window, 'setTimeout');

          const element = createElement({ warningOffsetInMilliseconds: 1000 });
          sandbox.stub(element, 'checkStatus');
          element.timeout = new Date(Date.now() + 999);

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
          element.timeout = new Date(Date.now() - 1);

          expect(window.setTimeout).not.to.have.been.called();
        });
      });

      context('timeout in the future', () => {
        it('schedules status check for timeout', () => {
          sandbox.stub(window, 'setTimeout');

          const element = createElement({ warningOffsetInMilliseconds: 1000 });
          sandbox.stub(element.modal, 'isVisible').get(() => true);
          element.timeout = new Date(Date.now() + 1);

          expect(window.setTimeout).to.have.been.calledWith(sinon.match.func, 1);
        });
      });
    });
  });

  it('re-schedules status check after keeping session alive', async () => {
    const timeout = new Date(Date.now() + 3000);
    requestSessionStatus.resolves({ isLive: true, timeout });
    createElement({ warningOffsetInMilliseconds: 1000, timeout });

    const modal = screen.getByRole('dialog') as ModalElement;
    expect(modal.isVisible).to.be.false();
    sandbox.clock.tick(2000);

    await waitFor(() => expect(modal.isVisible).to.be.true());

    const nextTimeout = new Date(Date.now() + 3000);
    extendSession.resolves({ isLive: true, timeout: nextTimeout });
    requestSessionStatus.reset();
    requestSessionStatus.resolves({ isLive: true, timeout: nextTimeout });

    const keepAliveButton = screen.getByRole('button', { name: 'Stay Signed In' });
    await userEvent.click(keepAliveButton);

    await waitFor(() => expect(modal.isVisible).to.be.false());
    expect(extendSession).to.have.been.called();

    sandbox.clock.tick(1000);
    expect(requestSessionStatus).not.to.have.been.called();

    sandbox.clock.tick(1000);
    expect(requestSessionStatus).to.have.been.called();
    await waitFor(() => expect(modal.isVisible).to.be.true());
  });
});
