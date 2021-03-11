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
 * Manages polling requests for document capture hybrid flow.
 */
export class DocumentCapturePolling {
  pollAttempts = 0;

  /**
   * @param {DocumentCapturePollingElements} elements
   */
  constructor(elements) {
    this.elements = elements;
  }

  bind() {
    this.toggleFormVisible(false);
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

  onComplete() {
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
        this.onComplete();
        break;

      default:
        this.schedulePoll();
        break;
    }
  }
}
