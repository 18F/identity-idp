import sinon from 'sinon';
import { getByRole } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import './click-observer-element';

describe('ClickObserverElement', () => {
  context('with an event name', () => {
    it('tracks event on click', async () => {
      document.body.innerHTML = `
        <lg-click-observer event-name="Button clicked">
          <button>Click me!</button>
        </lg-click-observer>`;
      const observer = document.body.querySelector('lg-click-observer')!;
      const trackEvent = sinon.stub(observer, 'trackEvent');

      const button = getByRole(document.body, 'button', { name: 'Click me!' });
      await userEvent.click(button);

      expect(trackEvent).to.have.been.calledWith('Button clicked');
    });
  });

  context('without an event name', () => {
    it('does nothing on click', async () => {
      document.body.innerHTML = `
        <lg-click-observer>
          <button>Click me!</button>
        </lg-click-observer>`;
      const observer = document.body.querySelector('lg-click-observer')!;
      const trackEvent = sinon.stub(observer, 'trackEvent');

      const button = getByRole(document.body, 'button', { name: 'Click me!' });
      await userEvent.click(button);

      expect(trackEvent).not.to.have.been.called();
    });
  });
});
