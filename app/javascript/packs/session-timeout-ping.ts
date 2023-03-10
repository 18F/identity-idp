import { forceRedirect } from '@18f/identity-url';
import { requestSessionStatus, extendSession, endSession } from '@18f/identity-session';
import type { SessionStatus } from '@18f/identity-session';
import type { CountdownElement } from '@18f/identity-countdown/countdown-element';
import type { ModalElement } from '@18f/identity-modal';

const warningEl = document.getElementById('session-timeout-cntnr');

const defaultTime = '60';

const frequency = parseInt(warningEl?.dataset.frequency || defaultTime, 10) * 1000;
const warning = parseInt(warningEl?.dataset.warning || defaultTime, 10) * 1000;
const start = parseInt(warningEl?.dataset.start || defaultTime, 10) * 1000;

const modal = document.querySelector<ModalElement>('lg-modal.session-timeout-modal')!;
const keepaliveEl = document.getElementById('session-keepalive-btn');
const countdownEls: NodeListOf<CountdownElement> = modal.querySelectorAll('lg-countdown');

async function handleTimeout() {
  const { redirect } = await endSession();
  forceRedirect(redirect);
}

function success(data: SessionStatus) {
  if (data.isLive) {
    const timeRemaining = data.timeout.valueOf() - Date.now();
    const showWarning = timeRemaining < warning;

    if (showWarning) {
      modal.show();
      countdownEls.forEach((countdownEl) => {
        countdownEl.expiration = data.timeout;
        countdownEl.start();
      });
    }

    const nextPingTimeout = Math.min(frequency, Math.max(timeRemaining, 0));
    // Disable reason: circular dependency between ping and success
    // eslint-disable-next-line @typescript-eslint/no-use-before-define
    setTimeout(ping, nextPingTimeout);
  } else {
    handleTimeout();
  }
}

const ping = () => requestSessionStatus().then(success);

function keepalive() {
  modal.hide();
  countdownEls.forEach((countdownEl) => countdownEl.stop());
  extendSession();
}

keepaliveEl?.addEventListener('click', keepalive, false);
setTimeout(ping, start);
