import { trackEvent as defaultTrackEvent } from '@18f/identity-analytics';

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
  THROTTLED = 'THROTTLED',
}

/**
 * Manages polling requests for document capture hybrid flow.
 */
export class DocumentCapturePolling {
  elements: DocumentCapturePollingElements;

  statusEndpoint: string;

  trackEvent: typeof defaultTrackEvent;

  pollAttempts = 0;

  constructor({
    elements,
    statusEndpoint,
    trackEvent = defaultTrackEvent,
  }: DocumentCapturePollingOptions) {
    this.elements = elements;
    this.statusEndpoint = statusEndpoint;
    this.trackEvent = trackEvent;
  }

  bind() {
    this.toggleFormVisible(false);
    this.trackEvent('IdV: Link sent capture doc polling started');
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
    window.onbeforeunload = shouldPrompt
      ? (event) => {
          event.preventDefault();
          event.returnValue = '';
        }
      : null;
  }

  onMaxPollAttempts() {
    this.toggleFormVisible(true);
  }

  async onComplete({ result, redirect }: { result: ResultType; redirect?: string }) {
    await this.trackEvent('IdV: Link sent capture doc polling complete', {
      isCancelled: result === ResultType.CANCELLED,
      isThrottled: result === ResultType.THROTTLED,
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
    const response = await window.fetch(this.statusEndpoint);
    const { redirect } = (await response.json()) as { redirect?: string };

    switch (response.status) {
      case StatusCodes.SUCCESS:
        this.onComplete({ result: ResultType.SUCCESS, redirect });
        break;

      case StatusCodes.GONE:
        this.onComplete({ result: ResultType.CANCELLED });
        break;

      case StatusCodes.TOO_MANY_REQUESTS: {
        this.onComplete({ result: ResultType.THROTTLED, redirect });
        break;
      }

      default:
        this.schedulePoll();
        break;
    }
  }
}
