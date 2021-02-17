/**
 * @typedef NewRelicAgent
 *
 * @prop {(name:string,attributes:object)=>void} addPageAction Log page action to New Relic.
 */

/**
 * @typedef LoginGov
 *
 * @prop {(any)=>void} Modal
 * @prop {(string)=>void} autoLogout
 * @prop {(el:HTMLElement?,timeLeft:number,endTime:number,interval?:number)=>void} countdownTimer
 */

/**
 * @typedef NewRelicGlobals
 *
 * @prop {NewRelicAgent=} newrelic New Relic agent.
 */

/**
 * @typedef LoginGovGlobals
 *
 * @prop {LoginGov} LoginGov
 */

/**
 * @typedef {typeof window & NewRelicGlobals & LoginGovGlobals} LoginGovGlobal
 */

const login = /** @type {LoginGovGlobal} */ (window).LoginGov;

const warningEl = document.getElementById('session-timeout-cntnr');

const defaultTime = '60000';

const frequency = parseInt(warningEl?.dataset.frequency || defaultTime, 10) * 1000;
const warning = parseInt(warningEl?.dataset.warning || defaultTime, 10) * 1000;
const start = parseInt(warningEl?.dataset.start || defaultTime, 10) * 1000;
const timeoutUrl = warningEl?.dataset.timeoutUrl;
const warningInfo = warningEl?.dataset.warningInfoHtml || '';
warningEl?.insertAdjacentHTML('afterbegin', warningInfo);
const initialTime = new Date();

const modal = new login.Modal({ el: '#session-timeout-msg' });
const keepaliveEl = document.getElementById('session-keepalive-btn');
/** @type {HTMLMetaElement?} */
const csrfEl = document.querySelector('meta[name="csrf-token"]');

let csrfToken = '';
if (csrfEl) {
  csrfToken = csrfEl.content;
}

let countdownInterval;

function notifyNewRelic(request, error, actionName) {
  /** @type {LoginGovGlobal} */ (window).newrelic?.addPageAction('Session Ping Error', {
    action_name: actionName,
    request_status: request.status,
    time_elapsed_ms: new Date().valueOf() - initialTime.valueOf(),
    error: error.message,
  });
}

function success(data) {
  let timeRemaining = data.remaining * 1000;
  const timeTimeout = new Date().getTime() + timeRemaining;
  const showWarning = timeRemaining < warning;

  if (!data.live) {
    login.autoLogout(timeoutUrl);
    return;
  }

  if (showWarning && !modal.shown) {
    modal.show();

    if (countdownInterval) {
      clearInterval(countdownInterval);
    }
    countdownInterval = login.countdownTimer(
      document.getElementById('countdown'),
      timeRemaining,
      timeTimeout,
    );
  }

  if (!showWarning && modal.shown) {
    modal.hide();
  }

  if (timeRemaining < frequency) {
    timeRemaining = timeRemaining < 0 ? 0 : timeRemaining;
    // Disable reason: circular dependency between ping and success
    // eslint-disable-next-line no-use-before-define
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
