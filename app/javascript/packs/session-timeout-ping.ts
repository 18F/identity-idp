import { forceRedirect } from '@18f/identity-url';
import { request } from '@18f/identity-request';
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

function success(data: PingResponse) {
  let timeRemaining = data.remaining * 1000;
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

  if (timeRemaining < frequency) {
    timeRemaining = timeRemaining < 0 ? 0 : timeRemaining;
    // Disable reason: circular dependency between ping and success
    // eslint-disable-next-line @typescript-eslint/no-use-before-define
    setTimeout(ping, timeRemaining);
  }
}

function ping() {
  try {
    request('/active').then(success);
  } catch (error) {
    notifyNewRelic(error, 'ping');
  }

  setTimeout(ping, frequency);
}

function keepalive() {
  try {
    request('/sessions/keepalive', { method: 'POST' }).then((data) => {
      success(data);
      modal.hide();
    });
  } catch (error) {
    notifyNewRelic(error, 'keepalive');
  }
}

keepaliveEl?.addEventListener('click', keepalive, false);
setTimeout(ping, start);
