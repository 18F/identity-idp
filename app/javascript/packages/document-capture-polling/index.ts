import { trackEvent as defaultTrackEvent } from '@18f/identity-analytics';
import { promptOnNavigate } from '@18f/identity-prompt-on-navigate';

export const DOC_CAPTURE_TIMEOUT = 1000 * 60 * 25; // 25 minutes
export const DOC_CAPTURE_POLL_INTERVAL = 5000;
export const MAX_DOC_CAPTURE_POLL_ATTEMPTS = Math.floor(
  DOC_CAPTURE_TIMEOUT / DOC_CAPTURE_POLL_INTERVAL,
);

interface DocumentCapturePollingElements {
  form: HTMLFormElement;

  backLink: HTMLAnchorElement;
}

interface DocumentCapturePollingOptions {
  statusEndpoint: string;

  elements: DocumentCapturePollingElements;

  phoneQuestionAbTestBucket: string | undefined;

  trackEvent?: typeof defaultTrackEvent;
}

enum StatusCodes {
  SUCCESS = 200,
  GONE = 410,
  TOO_MANY_REQUESTS = 429,
}

enum ResultType {
  SUCCESS = 'SUCCESS',
  CANCELLED = 'CANCELLED',
  RATE_LIMITED = 'RATE_LIMITED',
}

/**
 * Manages polling requests for document capture hybrid flow.
 */
export class DocumentCapturePolling {
  elements: DocumentCapturePollingElements;

  statusEndpoint: string;

  trackEvent: typeof defaultTrackEvent;

  pollAttempts = 0;

  cleanUpPromptOnNavigate: (() => void) | undefined;

  phoneQuestionAbTestBucket: string | undefined;

  constructor({
    elements,
    statusEndpoint,
    trackEvent = defaultTrackEvent,
    phoneQuestionAbTestBucket,
  }: DocumentCapturePollingOptions) {
    this.elements = elements;
    this.statusEndpoint = statusEndpoint;
    this.trackEvent = trackEvent;
    this.phoneQuestionAbTestBucket = phoneQuestionAbTestBucket;
  }

  bind() {
    this.toggleFormVisible(false);
    this.trackEvent('IdV: Link sent capture doc polling started', {
      phoneQuestionAbTestBucket: this.phoneQuestionAbTestBucket,
    });
    this.schedulePoll();
    this.bindPromptOnNavigate(true);
    this.elements.backLink.addEventListener('click', () => this.bindPromptOnNavigate(false));
  }

  toggleFormVisible(isVisible: boolean) {
    this.elements.form.classList.toggle('display-none', !isVisible);
  }

  /**
   * @param {boolean} shouldPrompt Whether to bind or unbind page unload behavior.
   */
  bindPromptOnNavigate(shouldPrompt) {
    const isAlreadyBound = !!this.cleanUpPromptOnNavigate;

    if (shouldPrompt && !isAlreadyBound) {
      this.cleanUpPromptOnNavigate = promptOnNavigate();
    } else if (!shouldPrompt && isAlreadyBound) {
      const cleanUp = this.cleanUpPromptOnNavigate ?? (() => {});
      this.cleanUpPromptOnNavigate = undefined;
      cleanUp();
    }
  }

  onMaxPollAttempts() {
    this.toggleFormVisible(true);
  }

  onComplete({ result, redirect }: { result: ResultType; redirect?: string }) {
    this.trackEvent('IdV: Link sent capture doc polling complete', {
      isCancelled: result === ResultType.CANCELLED,
      isRateLimited: result === ResultType.RATE_LIMITED,
      phoneQuestionAbTestBucket: this.phoneQuestionAbTestBucket,
    });
    this.bindPromptOnNavigate(false);
    if (redirect) {
      window.location.href = redirect;
    } else {
      this.elements.form.submit();
    }
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
    const response = await fetch(this.statusEndpoint);
    const { redirect } = (await response.json()) as { redirect?: string };

    switch (response.status) {
      case StatusCodes.SUCCESS:
        this.onComplete({ result: ResultType.SUCCESS, redirect });
        break;

      case StatusCodes.GONE:
        this.onComplete({ result: ResultType.CANCELLED });
        break;

      case StatusCodes.TOO_MANY_REQUESTS: {
        this.onComplete({ result: ResultType.RATE_LIMITED, redirect });
        break;
      }

      default:
        this.schedulePoll();
        break;
    }
  }
}
