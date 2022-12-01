import { t } from '@18f/identity-i18n';

export class CountdownElement extends HTMLElement {
  #pollIntervalId?: number;

  static observedAttributes = ['data-expiration'];

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
    return new Date(this.getAttribute('data-expiration')!);
  }

  set expiration(expiration: Date) {
    this.setAttribute('data-expiration', expiration.toISOString());
  }

  get timeRemaining(): number {
    return Math.max(this.expiration.getTime() - Date.now(), 0);
  }

  get updateInterval(): number {
    return Number(this.getAttribute('data-update-interval'));
  }

  get startImmediately(): boolean {
    return this.getAttribute('data-start-immediately') === 'true';
  }

  get #textNode(): Text {
    if (!this.firstChild) {
      this.appendChild(this.ownerDocument.createTextNode(''));
    }

    return this.firstChild as Text;
  }

  start(): void {
    this.stop();
    this.setTimeRemaining();
    this.#pollIntervalId = window.setInterval(() => this.tick(), this.updateInterval);
  }

  stop(): void {
    window.clearInterval(this.#pollIntervalId);
  }

  tick(): void {
    this.setTimeRemaining();

    if (this.timeRemaining <= 0) {
      this.stop();
    }
  }

  setTimeRemaining(): void {
    const { timeRemaining } = this;

    this.#textNode.nodeValue = [
      t('datetime.dotiw.minutes', { count: Math.floor(timeRemaining / 60000) }),
      t('datetime.dotiw.seconds', { count: Math.floor(timeRemaining / 1000) % 60 }),
    ].join(t('datetime.dotiw.two_words_connector'));
  }
}
