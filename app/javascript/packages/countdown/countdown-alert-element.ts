import type { CountdownElement } from './countdown-element';

export class CountdownAlertElement extends HTMLElement {
  connectedCallback() {
    if (this.showAtRemaining) {
      this.addEventListener('lg:countdown:tick', this.handleShowAtRemainingTick);
    }
  }

  get showAtRemaining(): number | null {
    return Number(this.getAttribute('show-at-remaining')) || null;
  }

  get countdown(): CountdownElement {
    return this.querySelector('lg-countdown')!;
  }

  handleShowAtRemainingTick = () => {
    if (this.countdown.timeRemaining <= this.showAtRemaining!) {
      this.show();
      this.removeEventListener('lg:countdown:tick', this.handleShowAtRemainingTick);
    }
  };

  show() {
    this.classList.remove('display-none');
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-countdown-alert': CountdownAlertElement;
  }
}

if (!customElements.get('lg-countdown-alert')) {
  customElements.define('lg-countdown-alert', CountdownAlertElement);
}
