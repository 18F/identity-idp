import type { CountdownElement } from './countdown-element';

export class CountdownAlertElement extends HTMLElement {
  connectedCallback() {
    if (this.showAtRemaining) {
      this.addEventListener('lg:countdown:tick', this.handleCountdownTick);
    }
  }

  get showAtRemaining(): number | null {
    return Number(this.getAttribute('show-at-remaining')) || null;
  }

  get redirectURL(): string | null {
    return this.getAttribute('redirect-url');
  }

  get countdown(): CountdownElement {
    return this.querySelector('lg-countdown')!;
  }

  handleCountdownTick = () => {
    this.showAtTimeRemaining();
    this.redirectOnTimeExpired();
  };

  showAtTimeRemaining() {
    if (this.countdown.timeRemaining <= this.showAtRemaining!) {
      this.show();
      this.removeEventListener('lg:countdown:tick', this.handleCountdownTick);
    }
  }

  redirectOnTimeExpired() {
    if (this.countdown.timeRemaining <= 0 && this.redirectURL) {
      window.location.href = this.redirectURL;
      // TODO: Redirect, but not using '`forceRedirect`
    }
  }

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
