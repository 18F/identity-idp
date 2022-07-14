import { forceRedirect } from '@18f/identity-url';
import type { CountdownElement } from '@18f/identity-countdown-element';

interface NewRelicAgent {
  /**
   * Log page action to New Relic.
   */
  addPageAction: (name: string, attributes: object) => void;
}

interface LoginGov {
  Modal: (any) => void;
}

interface NewRelicGlobals {
  /**
   * New Relic agent
   */
  newrelic?: NewRelicAgent;
}

interface LoginGovGlobals {
  LoginGov: LoginGov;
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

type LoginGovGlobal = typeof window & NewRelicGlobals & LoginGovGlobals;

const login = (window as LoginGovGlobal).LoginGov;

const warningEl = document.getElementById('session-timeout-cntnr');

const defaultTime = '60';

const frequency = parseInt(warningEl?.dataset.frequency || defaultTime, 10) * 1000;
const warning = parseInt(warningEl?.dataset.warning || defaultTime, 10) * 1000;
const start = parseInt(warningEl?.dataset.start || defaultTime, 10) * 1000;
const timeoutUrl = warningEl?.dataset.timeoutUrl;
const warningInfo = warningEl?.dataset.warningInfoHtml || '';
warningEl?.insertAdjacentHTML('afterbegin', warningInfo);
const initialTime = new Date();

const modal = new login.Modal({ el: '#session-timeout-msg' });
const keepaliveEl = document.getElementById('session-keepalive-btn');
const countdownEls: NodeListOf<CountdownElement> = modal.el.querySelectorAll('lg-countdown');
const csrfEl: HTMLMetaElement | null = document.querySelector('meta[name="csrf-token"]');

let csrfToken = '';
if (csrfEl) {
  csrfToken = csrfEl.content;
}

function notifyNewRelic(request, error, actionName) {
  (window as LoginGovGlobal).newrelic?.addPageAction('Session Ping Error', {
    action_name: actionName,
    request_status: request.status,
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

  if (showWarning && !modal.shown) {
    modal.show();
    countdownEls.forEach((countdownEl) => {
      countdownEl.expiration = new Date(data.timeout);
      countdownEl.start();
    });
  }

  if (!showWarning && modal.shown) {
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
  const request = new XMLHttpRequest();
  request.open('GET', '/active', true);

  request.onload = function () {
    try {
      success(JSON.parse(request.responseText));
    } catch (error) {
      notifyNewRelic(request, error, 'ping');
    }
  };

  request.send();
  setTimeout(ping, frequency);
}

function keepalive() {
  const request = new XMLHttpRequest();
  request.open('POST', '/sessions/keepalive', true);
  request.setRequestHeader('X-CSRF-Token', csrfToken);

  request.onload = function () {
    try {
      success(JSON.parse(request.responseText));
      modal.hide();
    } catch (error) {
      notifyNewRelic(request, error, 'keepalive');
    }
  };

  request.send();
}

keepaliveEl?.addEventListener('click', keepalive, false);
setTimeout(ping, start);
