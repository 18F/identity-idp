import { requestSessionStatus, extendSession } from '@18f/identity-session';
import type { CountdownElement } from '@18f/identity-countdown/countdown-element';
import type { ModalElement } from '@18f/identity-modal';

const expireConfig = document.getElementById('js-expire-session');

const defaultTime = '60';

const frequency = parseInt(expireConfig?.dataset.frequency || defaultTime, 10) * 1000;
const warning = parseInt(expireConfig?.dataset.warning || defaultTime, 10) * 1000;
const start = parseInt(expireConfig?.dataset.start || defaultTime, 10) * 1000;
const sessionsURL = expireConfig?.dataset.sessionsUrl!;
const sessionTimeout = parseInt(expireConfig?.dataset.sessionTimeoutIn || defaultTime, 10) * 1000;
const modal = document.querySelector<ModalElement>('lg-modal.session-timeout-modal')!;
const keepaliveEl = document.getElementById('session-keepalive-btn');
const countdownEls: NodeListOf<CountdownElement> = modal.querySelectorAll('lg-countdown');

let now = new Date();

let sessionTime = new Date(now.getTime() + sessionTimeout);

function success() {
  const timeRemaining = sessionTime.valueOf() - Date.now();
  const showWarning = timeRemaining < warning;
  if (showWarning) {
    modal.show();
    countdownEls.forEach((countdownEl) => {
      countdownEl.expiration = sessionTime;
      countdownEl.start();
    });
  }

  const nextPingTimeout =
    timeRemaining > 0 && timeRemaining < frequency ? timeRemaining : frequency;

  // Disable reason: circular dependency between ping and success
  // eslint-disable-next-line @typescript-eslint/no-use-before-define
  setTimeout(ping, nextPingTimeout);
}

const ping = () => {
  requestSessionStatus(sessionsURL).then(success);
};

function keepalive() {
  modal.hide();
  now = new Date();
  sessionTime = new Date(now.getTime() + sessionTimeout);
  countdownEls.forEach((countdownEl) => countdownEl.stop());
  extendSession(sessionsURL);
}

keepaliveEl?.addEventListener('click', keepalive, false);
setTimeout(ping, start);
