import { forceRedirect } from '@18f/identity-url';
import { request } from '@18f/identity-request';
import type { CountdownElement } from '@18f/identity-countdown/countdown-element';
import type { ModalElement } from '@18f/identity-modal';

interface PingResponse {
  /**
   * Whether the session is still active.
   */
  live: boolean;

  /**
   * Time remaining in active session, in seconds.
   */
  remaining: number;

  /**
   * ISO8601-formatted date string for session timeout.
   */
  timeout: string;
}

const warningEl = document.getElementById('session-timeout-cntnr');

const defaultTime = '60';

const frequency = parseInt(warningEl?.dataset.frequency || defaultTime, 10) * 1000;
const warning = parseInt(warningEl?.dataset.warning || defaultTime, 10) * 1000;
const start = parseInt(warningEl?.dataset.start || defaultTime, 10) * 1000;
const timeoutUrl = warningEl?.dataset.timeoutUrl;

const modal = document.querySelector<ModalElement>('lg-modal.session-timeout-modal')!;
const keepaliveEl = document.getElementById('session-keepalive-btn');
const countdownEls: NodeListOf<CountdownElement> = modal.querySelectorAll('lg-countdown');

function handleTimeout(redirectURL: string) {
  window.dispatchEvent(new window.CustomEvent('lg:session-timeout'));
  forceRedirect(redirectURL);
}

function success(data: PingResponse) {
  const timeRemaining = data.remaining * 1000;
  const showWarning = timeRemaining < warning;

  if (!data.live) {
    if (timeoutUrl) {
      handleTimeout(timeoutUrl);
    }
    return;
  }

  if (showWarning) {
    modal.show();
    countdownEls.forEach((countdownEl) => {
      countdownEl.expiration = new Date(data.timeout);
      countdownEl.start();
    });
  } else {
    modal.hide();
    countdownEls.forEach((countdownEl) => countdownEl.stop());
  }

  const nextPing = Math.min(frequency, Math.max(timeRemaining, 0));
  // Disable reason: circular dependency between ping and success
  // eslint-disable-next-line @typescript-eslint/no-use-before-define
  setTimeout(ping, nextPing);
}

const ping = () => request<PingResponse>('/active').then(success);

const keepalive = () =>
  request<PingResponse>('/sessions/keepalive', { method: 'POST' }).then(success);

keepaliveEl?.addEventListener('click', keepalive);
setTimeout(ping, start);
