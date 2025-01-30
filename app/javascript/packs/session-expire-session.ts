import { extendSession } from '@18f/identity-session';
import type { CountdownElement } from '@18f/identity-countdown/countdown-element';
import type { ModalElement } from '@18f/identity-modal';

const warningEl = document.getElementById('session-timeout-cntnr')!;

const warning = Number(warningEl.dataset.warning!) * 1000;
const sessionsURL = warningEl.dataset.sessionsUrl!;
const sessionTimeout = Number(warningEl.dataset.sessionTimeoutIn!) * 1000;
const modal = document.querySelector<ModalElement>('lg-modal.session-timeout-modal')!;
const keepaliveEl = document.getElementById('session-keepalive-btn');
const countdownEls: NodeListOf<CountdownElement> = modal.querySelectorAll('lg-countdown');
const timeoutRefreshPath = warningEl.dataset.timeoutRefreshPath || '';

let sessionExpiration = new Date(Date.now() + sessionTimeout);

function showModal() {
  modal.show();
  countdownEls.forEach((countdownEl) => {
    countdownEl.expiration = sessionExpiration;
    countdownEl.start();
  });
}

function keepalive() {
  modal.hide();
  if (new Date(Date.now()) > sessionExpiration) {
    document.location.href = timeoutRefreshPath;
  }
  sessionExpiration = new Date(Date.now() + sessionTimeout);

  setTimeout(showModal, sessionTimeout - warning);
  countdownEls.forEach((countdownEl) => countdownEl.stop());
  extendSession(sessionsURL);
}

keepaliveEl?.addEventListener('click', keepalive, false);
setTimeout(showModal, sessionTimeout - warning);
