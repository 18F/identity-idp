import { trackEvent } from '@18f/identity-analytics';
import type { CountdownElement } from './countdown-element';

export class CountdownAlertElement extends HTMLElement {
  connectedCallback() {
    if (this.showAtRemaining) {
      this.addEventListener('lg:countdown:tick', this.handleShowAtRemainingTick);
    }

    if (this.redirectURL) {
      this.addEventListener('lg:countdown:tick', this.handleRedirectTick);
    }
  }

  get showAtRemaining(): number | null {
    return Number(this.getAttribute('show-at-remaining')) || null;
  }

  get redirectURL(): string | null {
    return this.getAttribute('redirect-url') || null;
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

  handleRedirectTick = () => {
    if (this.countdown.timeRemaining <= 0) {
      trackEvent('Countdown timeout redirect', {
        path: this.redirectURL,
        expiration: this.countdown.expiration,
        timeRemaining: this.countdown.timeRemaining,
      });
      window.location.href = this.redirectURL!;
      this.removeEventListener('lg:countdown:tick', this.handleRedirectTick);
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
