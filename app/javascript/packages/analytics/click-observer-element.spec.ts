import sinon from 'sinon';
import { getByRole, getByText } from '@testing-library/dom';
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

    context('for a checkbox', () => {
      it('includes checked state in event payload', async () => {
        document.body.innerHTML = `
          <lg-click-observer event-name="Checkbox toggled">
            <input type="checkbox" aria-label="Toggle">
          </lg-click-observer>`;
        const observer = document.body.querySelector('lg-click-observer')!;
        const trackEvent = sinon.stub(observer, 'trackEvent');

        const button = getByRole(document.body, 'checkbox', { name: 'Toggle' });
        await userEvent.click(button);

        expect(trackEvent).to.have.been.calledWith('Checkbox toggled', { checked: true });
      });

      context('clicking on associated label', () => {
        it('logs a single event', async () => {
          document.body.innerHTML = `
            <lg-click-observer event-name="Checkbox toggled">
              <input type="checkbox" id="checkbox">
              <label for="checkbox">Toggle</label>
            </lg-click-observer>`;
          const observer = document.body.querySelector('lg-click-observer')!;
          const trackEvent = sinon.stub(observer, 'trackEvent');

          const label = getByText(document.body, 'Toggle');
          await userEvent.click(label);

          expect(trackEvent).to.have.been.calledOnceWith('Checkbox toggled', { checked: true });
        });
      });
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
