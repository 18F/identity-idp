import { usePropertyValue } from '@18f/identity-test-helpers';
import { TimeElement } from './index';

describe('TimeElement', () => {
  before(() => {
    if (!customElements.get('lg-time')) {
      customElements.define('lg-time', TimeElement);
    }
  });

  function createElement({ format, timestamp }: { format: string; timestamp: string }) {
    const element = document.createElement('lg-time');
    element.setAttribute('data-format', format);
    element.setAttribute('data-timestamp', timestamp);
    document.body.appendChild(element);
    return element;
  }

  it('sets text to formatted date', () => {
    const element = createElement({
      format: '%{month} %{day}, %{year} at %{hour}:%{minute} %{dayPeriod}',
      timestamp: new Date(2020, 3, 21, 14, 3, 24).toISOString(),
    });

    expect(element.textContent).to.equal('April 21, 2020 at 2:03 PM');
  });

  context('unassigned document lang', () => {
    usePropertyValue(document.documentElement, 'lang', '');

    it('sets text', () => {
      const element = createElement({
        format: '%{month} %{day}, %{year} at %{hour}:%{minute} %{dayPeriod}',
        timestamp: new Date(2020, 3, 21, 14, 3, 24).toISOString(),
      });

      expect(element.textContent).to.equal('April 21, 2020 at 2:03 PM');
    });
  });

  context('in locale which uses 24-hour time', () => {
    usePropertyValue(document.documentElement, 'lang', 'en-GB');

    it('sets text in 24-hour time, with empty dayPeriod', () => {
      const element = createElement({
        format: '%{month} %{day}, %{year} at %{hour}:%{minute} %{dayPeriod}',
        timestamp: new Date(2020, 3, 21, 14, 3, 24).toISOString(),
      });

      expect(element.textContent).to.equal('April 21, 2020 at 14:03');
    });
  });

  context('without formatToParts support', () => {
    usePropertyValue(Intl.DateTimeFormat.prototype, 'formatToParts', undefined);

    it('sets text using Intl.DateTimeFormat#format as fallback', () => {
      const element = createElement({
        format: '%{month} %{day}, %{year} at %{hour}:%{minute} %{dayPeriod}',
        timestamp: new Date(2020, 3, 21, 14, 3, 24).toISOString(),
      });

      expect(element.textContent).to.equal('April 21, 2020, 2:03 PM');
    });
  });
});
