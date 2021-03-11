import { trackEvent as defaultTrackEvent } from '@18f/identity-analytics';

export const DOC_CAPTURE_TIMEOUT = 1000 * 60 * 25; // 25 minutes
export const DOC_CAPTURE_POLL_INTERVAL = 5000;
export const MAX_DOC_CAPTURE_POLL_ATTEMPTS = Math.floor(
  DOC_CAPTURE_TIMEOUT / DOC_CAPTURE_POLL_INTERVAL,
);
export const POLL_ENDPOINT = '/verify/doc_auth/link_sent/poll';

/**
 * @typedef DocumentCapturePollingElements
 *
 * @prop {HTMLFormElement} form
 * @prop {HTMLParagraphElement} instructions
 */

/**
 * @typedef DocumentCapturePollingOptions
 *
 * @prop {DocumentCapturePollingElements} elements
 * @prop {typeof defaultTrackEvent=} trackEvent
 */

/**
 * Manages polling requests for document capture hybrid flow.
 */
export class DocumentCapturePolling {
  pollAttempts = 0;

  /**
   * @param {DocumentCapturePollingOptions} options
   */
  constructor({ elements, trackEvent = defaultTrackEvent }) {
    this.elements = elements;
    this.trackEvent = trackEvent;
  }

  bind() {
    this.toggleFormVisible(false);
    this.trackEvent('IdV: Link sent capture doc polling started');
    this.schedulePoll();
  }

  /**
   * @param {boolean} isVisible
   */
  toggleFormVisible(isVisible) {
    this.elements.form.classList.toggle('display-none', !isVisible);
    this.elements.instructions.classList.toggle('display-none', !isVisible);
  }

  onMaxPollAttempts() {
    this.toggleFormVisible(true);
  }

  async onComplete({ isCancelled }) {
    const event = `IdV: Link sent capture doc polling ${isCancelled ? 'cancelled' : 'complete'}`;
    await this.trackEvent(event);
    this.elements.form.submit();
  }

  schedulePoll() {
    if (this.pollAttempts >= MAX_DOC_CAPTURE_POLL_ATTEMPTS) {
      this.onMaxPollAttempts();
    } else {
      this.pollAttempts++;
      setTimeout(() => this.poll(), DOC_CAPTURE_POLL_INTERVAL);
    }
  }

  async poll() {
    const response = await window.fetch(POLL_ENDPOINT);

    switch (response.status) {
      case 200:
      case 410:
        this.onComplete({ isCancelled: response.status === 410 });
        break;

      default:
        this.schedulePoll();
        break;
    }
  }
}
