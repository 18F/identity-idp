import { replaceVariables } from '@18f/identity-i18n';

export class TimeElement extends HTMLElement {
  #format: string;

  #timestamp: string;

  connectedCallback() {
    this.#format = this.dataset.format as string;
    this.#timestamp = this.dataset.timestamp as string;

    this.setTime();
  }

  get date() {
    return new Date(this.#timestamp);
  }

  get locale() {
    return this.ownerDocument.documentElement.lang || undefined;
  }

  get formatter() {
    return new Intl.DateTimeFormat(this.locale, {
      month: 'long',
      day: 'numeric',
      year: 'numeric',
      hour: 'numeric',
      minute: 'numeric',
    });
  }

  setTime() {
    const { formatter } = this;
    if (typeof formatter.formatToParts === 'function') {
      const parts = formatter.formatToParts(this.date);
      const timeParts = Object.fromEntries(parts.map((part) => [part.type, part.value])) as Partial<
        Record<Intl.DateTimeFormatPartTypes, string>
      >;

      this.textContent = replaceVariables(this.#format, {
        dayPeriod: '',
        ...timeParts,
      }).trim();
    } else {
      // Degrade gracefully for environments where formatToParts is unsupported (Internet Explorer)
      this.textContent = formatter.format(this.date);
    }
  }
}
