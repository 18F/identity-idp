import sinon from 'sinon';
import { i18n } from '@18f/identity-i18n';
import { usePropertyValue } from '@18f/identity-test-helpers';
import { CountdownElement } from './index';

const DEFAULT_DATASET = {
  updateInterval: '1000',
  startImmediately: 'true',
  expiration: new Date().toISOString(),
};

describe('CountdownElement', () => {
  let clock: sinon.SinonFakeTimers;

  usePropertyValue(i18n, 'strings', {
    'datetime.dotiw.seconds': { one: 'one second', other: '%{count} seconds' },
    'datetime.dotiw.minutes': { one: 'one minute', other: '%{count} minutes' },
    'datetime.dotiw.two_words_connector': ' and ',
  });

  before(() => {
    if (!customElements.get('lg-countdown')) {
      customElements.define('lg-countdown', CountdownElement);
    }

    clock = sinon.useFakeTimers();
  });

  after(() => {
    clock.restore();
  });

  function createElement(dataset = {}) {
    const element = document.createElement('lg-countdown') as CountdownElement;
    Object.assign(element.dataset, DEFAULT_DATASET, dataset);
    document.body.appendChild(element);
    return element;
  }

  it('sets text to formatted date', () => {
    const element = createElement({
      expiration: new Date(new Date().getTime() + 62000).toISOString(),
    });

    expect(element.textContent).to.equal('one minute and 2 seconds');
  });

  it('schedules update after interval', () => {
    const element = createElement({
      expiration: new Date(new Date().getTime() + 3000).toISOString(),
      updateInterval: '2000',
    });

    clock.tick(1999);

    expect(element.textContent).to.equal('0 minutes and 3 seconds');

    clock.tick(1);

    expect(element.textContent).to.equal('0 minutes and one second');
  });

  it('allows a delayed start', () => {
    const element = createElement({
      expiration: new Date(new Date().getTime() + 1000).toISOString(),
      startImmediately: 'false',
    });

    clock.tick(1000);

    expect(element.textContent).to.equal('0 minutes and one second');

    element.start();

    expect(element.textContent).to.equal('0 minutes and 0 seconds');
  });

  it('can be stopped and restarted', () => {
    const element = createElement({
      expiration: new Date(new Date().getTime() + 2000).toISOString(),
      updateInterval: '1000',
    });

    element.stop();
    clock.tick(1000);

    expect(element.textContent).to.equal('0 minutes and 2 seconds');

    element.start();

    expect(element.textContent).to.equal('0 minutes and one second');
  });

  it('updates in response to changed expiration', () => {
    const element = createElement();

    element.expiration = new Date(new Date().getTime() + 1000);

    expect(element.textContent).to.equal('0 minutes and one second');

    element.setAttribute('data-expiration', new Date(new Date().getTime() + 2000).toISOString());

    expect(element.textContent).to.equal('0 minutes and 2 seconds');
  });

  describe('#start', () => {
    it('is idempotent', () => {
      const element = createElement({ startImmediately: 'false' });

      sinon.spy(element, 'setTimeRemaining');

      element.start();
      element.start();

      expect(clock.countTimers()).to.equal(1);
    });
  });
});
