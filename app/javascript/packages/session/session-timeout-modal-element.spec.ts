import { screen, waitFor } from '@testing-library/dom';
import baseUserEvent from '@testing-library/user-event';
import { useSandbox } from '@18f/identity-test-helpers';
import '@18f/identity-modal/modal-element';
import type ModalElement from '@18f/identity-modal/modal-element';
import type SessionTimeoutModalElement from './session-timeout-modal-element';
import './session-timeout-modal-element';

describe('SessionTimeoutModalElement', () => {
  const sandbox = useSandbox({ useFakeTimers: true });
  const userEvent = baseUserEvent.setup({ advanceTimers: sandbox.clock.tick });

  function createElement({
    warningOffsetInMilliseconds = 1000,
    timeout,
  }: Partial<Pick<SessionTimeoutModalElement, 'warningOffsetInMilliseconds' | 'timeout'>>) {
    document.body.innerHTML = `
      <lg-session-timeout-modal
        warning-offset-in-seconds="${warningOffsetInMilliseconds / 1000}"
        ${timeout ? `timeout="${timeout.toISOString()}"` : ''}
      >
        <lg-modal role="dialog" hidden>
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

  it('shows modal at warning offset', async () => {
    const timeout = new Date(Date.now() + 3000);
    const element = createElement({ warningOffsetInMilliseconds: 1000, timeout });
    sandbox.stub(element, 'requestSessionStatus').resolves({ isLive: true, timeout });

    const modal = screen.getByRole('dialog', { hidden: true }) as ModalElement;
    sandbox.clock.tick(2000);

    await waitFor(() => expect(modal.hidden).to.be.false());
  });

  it('re-schedules status check after keeping session alive', async () => {
    const timeout = new Date(Date.now() + 3000);
    const element = createElement({ warningOffsetInMilliseconds: 1000, timeout });
    const requestSessionStatus = sandbox.stub();
    requestSessionStatus.resolves({ isLive: true, timeout });
    sandbox.stub(element, 'requestSessionStatus').callsFake(requestSessionStatus);

    const modal = screen.getByRole('dialog', { hidden: true }) as ModalElement;
    sandbox.clock.tick(2000);

    await waitFor(() => expect(modal.hidden).to.be.false());

    const nextTimeout = new Date(Date.now() + 3000);
    sandbox.stub(element, 'extendSession').resolves({ isLive: true, timeout: nextTimeout });
    requestSessionStatus.reset();
    requestSessionStatus.resolves({ isLive: true, timeout: nextTimeout });

    const keepAliveButton = screen.getByRole('button', { name: 'Stay Signed In' });
    await userEvent.click(keepAliveButton);

    await waitFor(() => expect(modal.hidden).to.be.true());
    expect(element.extendSession).to.have.been.called();

    sandbox.clock.tick(1000);
    expect(requestSessionStatus).not.to.have.been.called();

    sandbox.clock.tick(1000);
    expect(requestSessionStatus).to.have.been.called();
    await waitFor(() => expect(modal.hidden).to.be.false());
  });
});
