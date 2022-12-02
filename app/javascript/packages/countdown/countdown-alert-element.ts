import { CountdownElement } from './countdown-element';

export class CountdownAlertElement extends HTMLElement {
  connectedCallback() {
    this.setVisibilityTimeout();
  }

  get showAtRemaining(): number | null {
    return Number(this.getAttribute('show-at-remaining')) || null;
  }

  get countdown(): CountdownElement {
    return this.querySelector('lg-countdown')!;
  }

  setVisibilityTimeout() {
    const { showAtRemaining } = this;
    if (!showAtRemaining) {
      return;
    }

    setTimeout(() => this.show(), this.countdown.timeRemaining - showAtRemaining);
  }

  show() {
    this.classList.remove('display-none');
  }
}

if (!customElements.get('lg-countdown-alert')) {
  customElements.define('lg-countdown-alert', CountdownAlertElement);
}
