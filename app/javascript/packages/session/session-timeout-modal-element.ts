import { forceRedirect } from '@18f/identity-url';
import type { ModalElement } from '@18f/identity-modal';
import type { CountdownElement } from '@18f/identity-countdown/countdown-element';
import { requestSessionStatus, extendSession } from './requests';

class SessionTimeoutModalElement extends HTMLElement {
  statusCheckTimeout: number;

  connectedCallback() {
    this.bindButtonEvents();
    this.scheduleStatusCheck();
  }

  disconnectedCallback() {
    this.clearScheduledStatusCheck();
  }

  /**
   * Amount of time before timeout to show modal.
   */
  get warningOffsetInMilliseconds(): number {
    return Number(this.getAttribute('warning-offset-in-seconds')!) * 1000;
  }

  get timeout(): Date | null {
    const timeout = this.getAttribute('timeout');
    return timeout ? new Date(timeout) : null;
  }

  set timeout(timeout: Date | null) {
    if (timeout) {
      this.setAttribute('timeout', timeout.toISOString());
    } else {
      this.removeAttribute('timeout');
    }

    this.scheduleStatusCheck();
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

  requestSessionStatus() {
    return requestSessionStatus();
  }

  extendSession() {
    return extendSession();
  }

  bindButtonEvents() {
    this.keepAliveButton.addEventListener('click', () => this.keepAlive());
  }

  async keepAlive() {
    this.clearScheduledStatusCheck();
    this.modal.hide();
    this.countdownElements.forEach((countdown) => countdown.stop());
    const { timeout } = await this.extendSession();
    this.timeout = timeout || null;
  }

  async checkStatus() {
    const { isLive, timeout } = await this.requestSessionStatus();

    if (isLive) {
      const millisecondsRemaining = timeout.valueOf() - Date.now();
      const showWarning = millisecondsRemaining <= this.warningOffsetInMilliseconds;
      if (showWarning) {
        this.modal.show();
        this.countdownElements.forEach((countdown) => {
          countdown.expiration = timeout;
          countdown.start();
        });
      }

      this.timeout = timeout;
    } else {
      forceRedirect(this.timeoutURL);
    }
  }

  scheduleStatusCheck() {
    this.clearScheduledStatusCheck();
    if (this.timeout) {
      const timeoutFromNow = this.timeout.valueOf() - Date.now();
      const delay = this.modal.hidden
        ? Math.max(timeoutFromNow - this.warningOffsetInMilliseconds, 0)
        : timeoutFromNow;

      this.statusCheckTimeout = window.setTimeout(() => this.checkStatus(), delay);
    }
  }

  clearScheduledStatusCheck() {
    window.clearTimeout(this.statusCheckTimeout);
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
