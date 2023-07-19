import { forceRedirect } from '@18f/identity-url';
import type { ModalElement } from '@18f/identity-modal';
import type { CountdownElement } from '@18f/identity-countdown/countdown-element';
import { requestSessionStatus, extendSession } from './requests';

class SessionTimeoutModalElement extends HTMLElement {
  statusCheckTimeout: number;

  connectedCallback() {
    this.bindButtonEvents();
    this.scheduleStatusCheck({ timeout: this.timeout });
  }

  disconnectedCallback() {
    window.clearTimeout(this.statusCheckTimeout);
  }

  /**
   * Amount of time before timeout to show modal, in milliseconds.
   */
  get warningOffset(): number {
    return Number(this.getAttribute('warning-offset-in-seconds')!) * 1000;
  }

  get timeout(): Date {
    return new Date(this.getAttribute('timeout')!);
  }

  get timeoutURL(): string {
    return this.getAttribute('timeout-url')!;
  }

  get modal(): ModalElement {
    return this.querySelector('lg-modal')!;
  }

  get keepAliveButton(): HTMLButtonElement {
    return this.querySelector<HTMLButtonElement>('.lg-session-timeout-modal__keep-alive-button')!;
  }

  get signOutButton(): HTMLButtonElement {
    return this.querySelector<HTMLButtonElement>('.lg-session-timeout-modal__sign-out-button')!;
  }

  get countdownElements(): CountdownElement[] {
    return Array.from(this.querySelectorAll('lg-countdown'));
  }

  bindButtonEvents() {
    this.keepAliveButton.addEventListener('click', () => this.keepAlive());
  }

  keepAlive() {
    this.modal.hide();
    this.countdownElements.forEach((countdown) => countdown.stop());
    extendSession();
  }

  async checkStatus() {
    const { isLive, timeout } = await requestSessionStatus();

    if (isLive) {
      const timeRemaining = timeout.valueOf() - Date.now();
      const showWarning = timeRemaining < this.warningOffset;
      if (showWarning) {
        this.modal.show();
        this.countdownElements.forEach((countdown) => {
          countdown.expiration = timeout;
          countdown.start();
        });
      }

      this.scheduleStatusCheck({ timeout });
    } else {
      forceRedirect(this.timeoutURL);
    }
  }

  scheduleStatusCheck({ timeout }: { timeout: Date }) {
    const timeoutFromNow = timeout.valueOf() - Date.now();
    const delay =
      timeoutFromNow < this.warningOffset ? timeoutFromNow : timeoutFromNow - this.warningOffset;

    if (delay > 0) {
      this.statusCheckTimeout = window.setTimeout(() => this.checkStatus(), delay);
    }
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-session-timeout-modal': SessionTimeoutModalElement;
  }
}

if (!customElements.get('lg-session-timeout-modal')) {
  customElements.define('lg-session-timeout-modal', SessionTimeoutModalElement);
}

export default SessionTimeoutModalElement;
