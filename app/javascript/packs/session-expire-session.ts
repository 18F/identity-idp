import { extendSession } from '@18f/identity-session';
import type { CountdownElement } from '@18f/identity-countdown/countdown-element';
import type { ModalElement } from '@18f/identity-modal';

const warningEl = document.getElementById('session-timeout-cntnr')!;

const warning = Number(warningEl.dataset.warning!) * 1000;
const sessionsURL = warningEl.dataset.sessionsUrl!;
const sessionTimeout = Number(warningEl.dataset.sessionTimeoutIn!) * 1000;
const modal = document.querySelector<ModalElement>('lg-modal.session-timeout-modal')!;
const keepaliveButton = document.getElementById('session-keepalive-btn')!;
const countdownEls: NodeListOf<CountdownElement> = modal.querySelectorAll('lg-countdown');

let sessionExpiration = new Date(Date.now() + sessionTimeout);

function showModal() {
  modal.show();
  countdownEls.forEach((countdownEl) => {
    countdownEl.expiration = sessionExpiration;
    countdownEl.start();
  });
}

function keepalive(event: MouseEvent) {
  const isExpired = new Date() > sessionExpiration;
  if (isExpired) {
    return;
  }

  event.preventDefault();
  modal.hide();
  sessionExpiration = new Date(Date.now() + sessionTimeout);

  setTimeout(showModal, sessionTimeout - warning);
  countdownEls.forEach((countdownEl) => countdownEl.stop());
  extendSession(sessionsURL);
}

keepaliveButton.addEventListener('click', keepalive);
setTimeout(showModal, sessionTimeout - warning);
