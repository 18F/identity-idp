import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
import { getByRole } from '@testing-library/dom';
import { SpinnerButton } from '../../../app/javascript/packs/spinner-button';

describe('SpinnerButton', () => {
  let clock;

  const longWaitDurationMs = 1000;

  function createWrapper({ actionMessage, tagName = 'a' } = {}) {
    document.body.innerHTML = `
      <div class="spinner-button" data-long-wait-duration-ms="${longWaitDurationMs}">
        <div class="spinner-button__content">
          ${tagName === 'a' ? '<a href="#">Click Me</a>' : '<input type="submit" value="Click Me">'}
          <span class="spinner-button__spinner" aria-hidden="true">
            <span class="spinner-button__spinner-dot"></span>
            <span class="spinner-button__spinner-dot"></span>
            <span class="spinner-button__spinner-dot"></span>
          </span>
        </div>
        ${
          actionMessage &&
          `<div
            role="status"
            data-message="${actionMessage}"
            class="spinner-button__action-message usa-sr-only"></div>`
        }
      </div>`;

    return document.body.firstElementChild;
  }

  beforeEach(() => {
    clock = sinon.useFakeTimers();
  });

  afterEach(() => {
    clock.restore();
  });

  it('shows spinner on click', () => {
    const wrapper = createWrapper();
    const { button } = new SpinnerButton(wrapper).elements;

    userEvent.click(button);

    expect(wrapper.classList.contains('spinner-button--spinner-active')).to.be.true();
  });

  it('disables button without preventing form handlers', () => {
    const wrapper = createWrapper({ tagName: 'button' });
    let submitted = false;
    const form = document.createElement('form');
    form.action = '#';
    form.addEventListener('submit', (event) => {
      submitted = true;
      event.preventDefault();
    });
    document.body.appendChild(form);
    form.appendChild(wrapper);
    const { button } = new SpinnerButton(wrapper).elements;

    userEvent.type(button, '{enter}');
    clock.tick(0);

    expect(submitted).to.be.true();
    expect(button.hasAttribute('disabled')).to.be.true();
  });

  it('announces action message', () => {
    const wrapper = createWrapper({ actionMessage: 'Verifying...' });
    const status = getByRole(wrapper, 'status');
    const { button } = new SpinnerButton(wrapper).elements;

    expect(status.textContent).to.be.empty();

    userEvent.click(button);

    expect(status.textContent).to.equal('Verifying...');
    expect(status.classList.contains('usa-sr-only')).to.be.true();
  });

  it('shows action message visually after long delay', () => {
    const wrapper = createWrapper({ actionMessage: 'Verifying...' });
    const status = getByRole(wrapper, 'status');
    const { button } = new SpinnerButton(wrapper).elements;

    expect(status.textContent).to.be.empty();

    userEvent.click(button);
    clock.tick(longWaitDurationMs - 1);
    expect(status.classList.contains('usa-sr-only')).to.be.true();
    clock.tick(1);
    expect(status.classList.contains('usa-sr-only')).to.be.false();
  });
});
