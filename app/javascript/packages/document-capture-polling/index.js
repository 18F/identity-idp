import { trackEvent as defaultTrackEvent } from '@18f/identity-analytics';

export const DOC_CAPTURE_TIMEOUT = 1000 * 60 * 25; // 25 minutes
export const DOC_CAPTURE_POLL_INTERVAL = 5000;
export const MAX_DOC_CAPTURE_POLL_ATTEMPTS = Math.floor(
  DOC_CAPTURE_TIMEOUT / DOC_CAPTURE_POLL_INTERVAL,
);

/**
 * @typedef DocumentCapturePollingElements
 *
 * @prop {HTMLFormElement} form
 * @prop {HTMLParagraphElement} instructions
 */

/**
 * @typedef DocumentCapturePollingOptions
 *
 * @prop {string} statusEndpoint
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
  constructor({ elements, statusEndpoint, trackEvent = defaultTrackEvent }) {
    this.elements = elements;
    this.statusEndpoint = statusEndpoint;
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

  /**
   * @param {{ isCancelled: boolean }} params
   */
  async onComplete({ isCancelled }) {
    await this.trackEvent('IdV: Link sent capture doc polling complete', { isCancelled });
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
    const response = await window.fetch(this.statusEndpoint);

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
