import { forceRedirect } from '@18f/identity-url';
import type { CountdownElement } from '@18f/identity-countdown/countdown-element';

const countdownEl = document.querySelector('lg-countdown-alert');

const defaultTime = '60';

const frequency = parseInt(countdownEl?.dataset.frequency || defaultTime, 10) * 1000;
const warning = parseInt(countdownEl?.dataset.warning || defaultTime, 10) * 1000;
const start = parseInt(countdownEl?.dataset.start || defaultTime, 10) * 1000;
const timeoutUrl = countdownEl?.dataset.timeoutUrl;
const initialTime = new Date();

// const countdownEls: NodeListOf<CountdownElement> = modal.querySelectorAll('lg-countdown');

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
      // notifyNewRelic(request, error, 'ping');
    }
  };

  request.send();
  setTimeout(ping, frequency);
}

setTimeout(ping, start);
