import { t } from '@18f/identity-i18n';
import { forceRedirect } from '@18f/identity-url';

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
    this.dispatchEvent(new window.CustomEvent('lg:countdown:tick', { bubbles: true }));

    if (this.timeRemaining <= 0) {
      this.stop();
      this.handleRedirect('/login/two_factor/sms_expired');
    }
  }

  setTimeRemaining(): void {
    const { timeRemaining } = this;

    const minutes = Math.floor(timeRemaining / 60000);
    const seconds = Math.floor(timeRemaining / 1000) % 60;

    this.#textNode.nodeValue = [
      minutes && t('datetime.dotiw.minutes', { count: minutes }),
      t('datetime.dotiw.seconds', { count: seconds }),
    ]
      .filter(Boolean)
      .join(t('datetime.dotiw.two_words_connector'));
  }

  handleRedirect(url: string): void {
    forceRedirect(url);
  }
}

if (!customElements.get('lg-countdown')) {
  customElements.define('lg-countdown', CountdownElement);
}
