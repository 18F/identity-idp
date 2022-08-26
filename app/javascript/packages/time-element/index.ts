import { replaceVariables } from '@18f/identity-i18n';

const snakeCase = (string: string): string =>
  string.replace(/[a-z][A-Z]/g, (match) => `${match[0]}_${match[1].toLowerCase()}`);

const mapKeys = (object: object, predicate: (key: string) => string) =>
  Object.fromEntries(Object.entries(object).map(([key, value]) => [predicate(key), value]));

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
    const is12Hour = this.#format.includes('%{day_period}');

    return new Intl.DateTimeFormat(this.locale, {
      month: 'long',
      day: 'numeric',
      year: 'numeric',
      hour: 'numeric',
      minute: 'numeric',
      hour12: is12Hour,
    });
  }

  setTime() {
    const { formatter } = this;
    if (typeof formatter.formatToParts === 'function') {
      const parts = Object.fromEntries(
        formatter.formatToParts(this.date).map((part) => [part.type, part.value]),
      ) as Partial<Record<Intl.DateTimeFormatPartTypes, string>>;

      this.textContent = replaceVariables(
        this.#format,
        mapKeys({ dayPeriod: '', ...parts }, snakeCase),
      );
    } else {
      // Degrade gracefully for environments where formatToParts is unsupported (Internet Explorer)
      this.textContent = formatter.format(this.date);
    }
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-time': TimeElement;
  }
}
