import type { CountdownElement } from './countdown-element';

type Phase = { at_s: number; type: 'info' | 'warning' | 'error'; label: string };

export class CountdownAlertElement extends HTMLElement {
  #currentPhaseKey?: string;

  connectedCallback() {
    this.addEventListener('lg:countdown:tick', this.#onTick);
    this.#updatePhaseForRemaining(this.#remaining());
  }

  disconnectedCallback() {
    this.removeEventListener('lg:countdown:tick', this.#onTick);
  }

  get countdown(): CountdownElement {
    return this.querySelector('lg-countdown')!;
  }

  get labelEl(): HTMLElement | null {
    return this.querySelector('[data-role="phase-label"]');
  }

  get phases(): Phase[] {
    try {
      return (JSON.parse(this.dataset.phases || '[]') as Phase[]).sort((a, b) => a.at_s - b.at_s);
    } catch {
      return [];
    }
  }

  get typeClasses(): Record<string, string[]> {
    try {
      return JSON.parse(this.dataset.typeClasses || '{}');
    } catch {
      return {};
    }
  }

  get srPhaseRegion(): HTMLElement | null {
    const id = this.dataset.srPhaseRegionId || '';
    return id ? document.getElementById(id) : null;
  }

  get srExpiryRegion(): HTMLElement | null {
    const id = this.dataset.srExpiryRegionId || '';
    return id ? document.getElementById(id) : null;
  }

  #ensureFallbackLiveRegions() {
    if (!this.srPhaseRegion) {
      const n = document.createElement('div');
      n.className = 'usa-sr-only';
      n.setAttribute('aria-live', 'polite');
      n.setAttribute('aria-atomic', 'true');
      n.id = 'otp-live-phase-fallback';
      document.body.appendChild(n);
      this.dataset.srPhaseRegionId = n.id;
    }
    if (!this.srExpiryRegion) {
      const n = document.createElement('div');
      n.className = 'usa-sr-only';
      n.setAttribute('role', 'alert');
      n.setAttribute('aria-atomic', 'true');
      n.id = 'otp-live-expiry-fallback';
      document.body.appendChild(n);
      this.dataset.srExpiryRegionId = n.id;
    }
  }

  #onTick = () => {
    this.#updatePhaseForRemaining(this.#remaining());
  };

  #remaining(): number {
    return Math.ceil(this.countdown.timeRemaining / 1000);
  }

  // review DOM updates, innerHTML vs. textContent issues
  #updatePhaseForRemaining(remainingS: number) {
    if (!this.phases.length) {
      return;
    }
    this.#ensureFallbackLiveRegions();

    const active =
      this.phases.find((p) => p.at_s >= remainingS) ?? this.phases[this.phases.length - 1];

    const key = `${active.type}:${active.at_s}`;
    if (this.#currentPhaseKey === key) {
      return;
    }

    if (this.labelEl) {
      this.labelEl.innerHTML = active.label;
    }
    this.#swapTypeClasses(active.type);

    if (active.at_s > 0) {
      this.srPhaseRegion && (this.srPhaseRegion.textContent = active.label);
    } else {
      this.srExpiryRegion && (this.srExpiryRegion.textContent = active.label);
      this.srPhaseRegion && (this.srPhaseRegion.textContent = '');
    }

    this.#currentPhaseKey = key;
  }

  #swapTypeClasses(type: Phase['type']) {
    const alert = this.querySelector('.usa-alert');
    if (!alert) {
      return;
    }

    const allKnown = [
      ...(this.typeClasses.info || []),
      ...(this.typeClasses.warning || []),
      ...(this.typeClasses.error || []),
    ];
    allKnown.forEach((c) => alert.classList.remove(c));
    (this.typeClasses[type] || []).forEach((c) => alert.classList.add(c));
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
