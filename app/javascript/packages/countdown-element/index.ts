import { t } from '@18f/identity-i18n';

export interface CountdownElementDataset {
  /**
   * ISO8601-formatted date string for countdown expiration time.
   */
  expiration: string;

  /**
   * Interval at which text is updated, in milliseconds.
   */
  updateInterval: string;

  /**
   * Whether to start the countdown as soon as the element is connected.
   */
  startImmediately: 'true' | 'false';
}

export class CountdownElement extends HTMLElement {
  #pollIntervalId?: number;

  dataset: CountdownElementDataset & DOMStringMap;

  static get observedAttributes() {
    return ['data-expiration'];
  }

  connectedCallback() {
    if (this.startImmediately) {
      this.start();
    } else {
      this.setTimeRemaining();
    }
  }

  disconnectedCallback() {
    this.stop();
  }

  attributeChangedCallback() {
    this.setTimeRemaining();
  }

  get expiration(): Date {
    return new Date(this.dataset.expiration);
  }

  set expiration(expiration: Date) {
    this.setAttribute('data-expiration', expiration.toISOString());
  }

  get timeRemaining(): number {
    return Math.max(this.expiration.getTime() - Date.now(), 0);
  }

  get updateInterval(): number {
    return Number(this.dataset.updateInterval);
  }

  get startImmediately(): boolean {
    return this.dataset.startImmediately === 'true';
  }

  start(): void {
    this.setTimeRemaining();
    this.#pollIntervalId = window.setInterval(() => this.setTimeRemaining(), this.updateInterval);
  }

  stop(): void {
    window.clearInterval(this.#pollIntervalId);
  }

  setTimeRemaining(): void {
    const { timeRemaining } = this;

    this.textContent = [
      t('datetime.dotiw.minutes', { count: Math.floor(timeRemaining / 60000) }),
      t('datetime.dotiw.seconds', { count: Math.floor(timeRemaining / 1000) % 60 }),
    ].join(t('datetime.dotiw.two_words_connector'));
  }
}
