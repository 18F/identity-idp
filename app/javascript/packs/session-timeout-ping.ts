import { forceRedirect } from '@18f/identity-url';
import { requestSessionStatus, extendSession } from '@18f/identity-session';
import type { SessionStatus } from '@18f/identity-session';
import type { CountdownElement } from '@18f/identity-countdown/countdown-element';
import type { ModalElement } from '@18f/identity-modal';

interface NewRelicAgent {
  /**
   * Log page action to New Relic.
   */
  addPageAction: (name: string, attributes: object) => void;
}

interface NewRelicGlobals {
  /**
   * New Relic agent
   */
  newrelic?: NewRelicAgent;
}

type LoginGovGlobal = typeof window & NewRelicGlobals;

const warningEl = document.getElementById('session-timeout-cntnr');

const defaultTime = '60';

const frequency = parseInt(warningEl?.dataset.frequency || defaultTime, 10) * 1000;
const warning = parseInt(warningEl?.dataset.warning || defaultTime, 10) * 1000;
const start = parseInt(warningEl?.dataset.start || defaultTime, 10) * 1000;
const timeoutUrl = warningEl?.dataset.timeoutUrl;
const initialTime = new Date();

const modal = document.querySelector<ModalElement>('lg-modal.session-timeout-modal')!;
const keepaliveEl = document.getElementById('session-keepalive-btn');
const countdownEls: NodeListOf<CountdownElement> = modal.querySelectorAll('lg-countdown');

function notifyNewRelic(error, actionName) {
  (window as LoginGovGlobal).newrelic?.addPageAction('Session Ping Error', {
    action_name: actionName,
    time_elapsed_ms: new Date().valueOf() - initialTime.valueOf(),
    error: error.message,
  });
}

function handleTimeout(redirectURL: string) {
  window.dispatchEvent(new window.CustomEvent('lg:session-timeout'));
  forceRedirect(redirectURL);
}

function success({ isLive, timeout }: SessionStatus) {
  if (!isLive) {
    if (timeoutUrl) {
      handleTimeout(timeoutUrl);
    }
    return;
  }

  const timeRemaining = timeout.valueOf() - Date.now();
  const showWarning = timeRemaining < warning;
  if (showWarning) {
    modal.show();
    countdownEls.forEach((countdownEl) => {
      countdownEl.expiration = timeout;
      countdownEl.start();
    });
  }

  if (timeRemaining > 0 && timeRemaining < frequency) {
    // Disable reason: circular dependency between ping and success
    // eslint-disable-next-line @typescript-eslint/no-use-before-define
    setTimeout(ping, timeRemaining);
  }
}

function ping() {
  requestSessionStatus()
    .then(success)
    .catch((error) => notifyNewRelic(error, 'ping'));

  setTimeout(ping, frequency);
}

function keepalive() {
  modal.hide();
  countdownEls.forEach((countdownEl) => countdownEl.stop());
  extendSession().catch((error) => notifyNewRelic(error, 'keepalive'));
}

keepaliveEl?.addEventListener('click', keepalive, false);
setTimeout(ping, start);
