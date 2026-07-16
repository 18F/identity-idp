import zxcvbn from 'zxcvbn';
import { t } from '@18f/identity-i18n';
import type { ZXCVBNResult, ZXCVBNScore } from 'zxcvbn';

const MINIMUM_STRENGTH: ZXCVBNScore = 3;

type DisplayScore = 1 | 2 | 3;

const prefersReducedMotion = () =>
  window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;

const hasRevealTransition = (element: HTMLElement) => {
  if (prefersReducedMotion()) {
    return false;
  }

  const duration = window.getComputedStyle(element).transitionDuration || '0s';
  return duration.split(',').some((part) => Number.parseFloat(part) > 0);
};

class PasswordStrengthElement extends HTMLElement {
  #onTransitionEnd?: (event: TransitionEvent) => void;

  connectedCallback() {
    this.input?.addEventListener('input', this.#onInput);
    this.#sync();
  }

  disconnectedCallback() {
    this.input?.removeEventListener('input', this.#onInput);
    this.#cancelClose();
  }

  get feedback(): HTMLElement {
    return this.querySelector('.ads-password-strength__feedback')!;
  }

  get input(): HTMLInputElement | null {
    const id = this.getAttribute('input-id');
    if (!id) {
      return null;
    }

    const el = this.ownerDocument.getElementById(id);
    return el instanceof HTMLInputElement ? el : null;
  }

  get minimumLength(): number {
    return Number(this.getAttribute('minimum-length')!);
  }

  get forbiddenPasswords(): string[] {
    return JSON.parse(this.getAttribute('forbidden-passwords') || '[]');
  }

  #onInput = () => {
    this.#sync();
  };

  #displayScore(result: ZXCVBNResult, value: string): DisplayScore {
    let { score } = result;
    if (score >= MINIMUM_STRENGTH && value.length < this.minimumLength) {
      score = (MINIMUM_STRENGTH - 1) as ZXCVBNScore;
    }
    if (score >= 3) {
      return 3;
    }
    if (score === 2) {
      return 2;
    }
    return 1;
  }

  #feedbackText(result: ZXCVBNResult, value: string): string {
    if (this.forbiddenPasswords.includes(value)) {
      return t('instructions.password.strength.too_common');
    }

    const score = this.#displayScore(result, value);
    if (score === 1) {
      return t('instructions.password.strength.1');
    }
    if (score === 2) {
      return t('instructions.password.strength.3');
    }
    return t('instructions.password.strength.strong');
  }

  #isValid(result: ZXCVBNResult, value: string): boolean {
    return (
      !this.forbiddenPasswords.includes(value) &&
      result.score >= MINIMUM_STRENGTH &&
      value.length >= this.minimumLength
    );
  }

  #setDescribedBy(active: boolean) {
    const { input } = this;
    if (!input) {
      return;
    }

    const feedbackId = this.feedback.id;
    const current = (input.getAttribute('aria-describedby') || '')
      .split(/\s+/)
      .filter(Boolean)
      .filter((id) => id !== feedbackId);

    if (active && feedbackId) {
      current.push(feedbackId);
    }

    if (current.length) {
      input.setAttribute('aria-describedby', current.join(' '));
    } else {
      input.removeAttribute('aria-describedby');
    }
  }

  #cancelClose() {
    if (this.#onTransitionEnd) {
      this.removeEventListener('transitionend', this.#onTransitionEnd);
      this.removeEventListener('transitioncancel', this.#onTransitionEnd);
      this.#onTransitionEnd = undefined;
    }
  }

  #clearMeter() {
    this.removeAttribute('data-score');
    this.feedback.textContent = '';
  }

  #reveal() {
    this.#cancelClose();

    if (!this.hidden && this.dataset.open === 'true') {
      return;
    }

    this.hidden = false;

    if (!hasRevealTransition(this)) {
      this.dataset.open = 'true';
      return;
    }

    this.dataset.open = 'false';
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        if (this.hidden) {
          return;
        }
        this.dataset.open = 'true';
      });
    });
  }

  #collapse() {
    this.#cancelClose();
    this.#clearMeter();

    const finish = () => {
      this.#cancelClose();
      this.hidden = true;
      this.dataset.open = 'false';
    };

    if (this.hidden || this.dataset.open !== 'true') {
      finish();
      return;
    }

    this.dataset.open = 'false';

    if (!hasRevealTransition(this)) {
      finish();
      return;
    }

    this.#onTransitionEnd = (event: TransitionEvent) => {
      if (event.target === this && event.propertyName === 'grid-template-rows') {
        finish();
      }
    };

    this.addEventListener('transitionend', this.#onTransitionEnd);
    this.addEventListener('transitioncancel', this.#onTransitionEnd);
  }

  #sync() {
    const { input } = this;
    if (!input) {
      return;
    }

    const { value } = input;
    const hasValue = value.length > 0;

    if (!hasValue) {
      this.#collapse();
      this.#setDescribedBy(false);
      input.setCustomValidity('');
      return;
    }

    // Reveal immediately so layout shifts once as the user starts typing.
    this.#reveal();

    const result = zxcvbn(value, this.forbiddenPasswords);
    const score = this.#displayScore(result, value);

    this.dataset.score = String(score);
    this.feedback.textContent = this.#feedbackText(result, value);
    this.#setDescribedBy(true);
    input.setCustomValidity(
      this.#isValid(result, value) ? '' : t('errors.messages.stronger_password'),
    );
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-password-strength': PasswordStrengthElement;
  }
}

if (!customElements.get('lg-password-strength')) {
  customElements.define('lg-password-strength', PasswordStrengthElement);
}

export default PasswordStrengthElement;
