import sinon from 'sinon';
import { i18n } from '@18f/identity-i18n';
import { usePropertyValue, useSandbox } from '@18f/identity-test-helpers';
import { CountdownElement } from './countdown-element';

const DEFAULT_DATASET = {
  updateInterval: '1000',
  startImmediately: 'true',
  expiration: new Date().toISOString(),
};

describe('CountdownElement', () => {
  const { clock } = useSandbox({ useFakeTimers: true });

  usePropertyValue(i18n, 'strings', {
    'datetime.dotiw.seconds': { one: 'one second', other: '%{count} seconds' },
    'datetime.dotiw.minutes': { one: 'one minute', other: '%{count} minutes' },
    'datetime.dotiw.two_words_connector': ' and ',
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

    expect(element.textContent).to.equal('3 seconds');

    clock.tick(1);

    expect(element.textContent).to.equal('one second');
  });

  it('allows a delayed start', () => {
    const element = createElement({
      expiration: new Date(new Date().getTime() + 1000).toISOString(),
      startImmediately: 'false',
    });

    clock.tick(1000);

    expect(element.textContent).to.equal('one second');

    element.start();

    expect(element.textContent).to.equal('0 seconds');
  });

  it('can be stopped and restarted', () => {
    const element = createElement({
      expiration: new Date(new Date().getTime() + 2000).toISOString(),
      updateInterval: '1000',
    });

    element.stop();
    clock.tick(1000);

    expect(element.textContent).to.equal('2 seconds');

    element.start();

    expect(element.textContent).to.equal('one second');
  });

  it('updates in response to changed expiration', () => {
    const element = createElement();

    element.expiration = new Date(new Date().getTime() + 1000);

    expect(element.textContent).to.equal('one second');

    element.setAttribute('data-expiration', new Date(new Date().getTime() + 2000).toISOString());

    expect(element.textContent).to.equal('2 seconds');
  });

  it('stops when the countdown is finished', () => {
    const element = createElement({
      expiration: new Date(new Date().getTime() + 1000).toISOString(),
      updateInterval: '1000',
    });

    sinon.spy(element, 'stop');

    clock.tick(1000);

    expect(element.textContent).to.equal('0 seconds');
    expect(element.stop).to.have.been.called();
  });

  it('emits a tick event on each tick', () => {
    const element = createElement({
      expiration: new Date(new Date().getTime() + 2000).toISOString(),
      updateInterval: '1000',
    });

    const onTick = sinon.stub();
    document.body.addEventListener('lg:countdown:tick', onTick);

    clock.tick(1000);

    expect(onTick).to.have.been.calledOnce();
    const event: CustomEvent = onTick.getCall(0).args[0];
    expect(event.target).to.equal(element);
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
