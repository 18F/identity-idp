import baseUserEvent from '@testing-library/user-event';
import { getByRole, fireEvent, screen } from '@testing-library/dom';
import type { SinonStub } from 'sinon';
import { useSandbox } from '@18f/identity-test-helpers';
import './spinner-button-element';

describe('SpinnerButtonElement', () => {
  const sandbox = useSandbox({ useFakeTimers: true });
  const { clock } = sandbox;
  const userEvent = baseUserEvent.setup({ advanceTimers: clock.tick });

  const longWaitDurationMs = 1000;

  interface WrapperOptions {
    actionMessage?: string;
    tagName?: string;
    spinOnClick?: boolean;
    inForm?: boolean;
    isButtonTo?: boolean;
  }

  function createWrapper({
    actionMessage,
    tagName = 'a',
    spinOnClick,
    inForm,
    isButtonTo,
  }: WrapperOptions = {}) {
    let tag;
    if (tagName === 'a') {
      tag = '<a href="#">Click Me</a>';
    } else {
      tag = '<input type="submit" value="Click Me">';
    }

    if (isButtonTo) {
      tag = `<form action="#">${tag}</form>`;
    }

    let html = `
      <lg-spinner-button
        long-wait-duration-ms="${longWaitDurationMs}"
        ${spinOnClick === undefined ? '' : `spin-on-click="${spinOnClick}"`}
      >
        <div class="spinner-button__content">
          ${tag}
          <span class="spinner-dots" aria-hidden="true">
            <span class="spinner-dots__dot"></span>
            <span class="spinner-dots__dot"></span>
            <span class="spinner-dots__dot"></span>
          </span>
        </div>
        ${
          actionMessage
            ? `<div
                 role="status"
                 data-message="${actionMessage}"
                 class="spinner-button__action-message usa-sr-only"></div>`
            : ''
        }
      </lg-spinner-button>`;

    if (inForm) {
      html = `<form action="#">${html}</form>`;
    }

    document.body.innerHTML = html;

    return document.querySelector('lg-spinner-button')!;
  }

  it('shows spinner on click', async () => {
    const wrapper = createWrapper();
    const button = screen.getByRole('link', { name: 'Click Me' });

    await userEvent.click(button);

    expect(wrapper.classList.contains('spinner-button--spinner-active')).to.be.true();
  });

  context('inside form', () => {
    it('disables button without preventing form handlers', async () => {
      const wrapper = createWrapper({ tagName: 'button', inForm: true });
      let didSubmit = false;
      wrapper.form!.addEventListener('submit', (event) => {
        didSubmit = true;
        event.preventDefault();
      });
      const button = screen.getByRole('button', { name: 'Click Me' });

      await userEvent.type(button, '{Enter}');
      clock.tick(0);

      expect(didSubmit).to.be.true();
      expect(button.hasAttribute('disabled')).to.be.true();
    });

    it('unbinds events when disconnected', () => {
      const wrapper = createWrapper({ tagName: 'button', inForm: true });
      const form = wrapper.form!;
      form.removeChild(wrapper);

      sandbox.spy(wrapper, 'toggleSpinner');
      fireEvent.submit(form);

      expect(wrapper.toggleSpinner).not.to.have.been.called();
    });
  });

  context('with form inside (button_to)', () => {
    it('disables button without preventing form handlers', async () => {
      const wrapper = createWrapper({ tagName: 'button', isButtonTo: true });
      let didSubmit = false;
      wrapper.form!.addEventListener('submit', (event) => {
        didSubmit = true;
        event.preventDefault();
      });
      const button = screen.getByRole('button', { name: 'Click Me' });

      await userEvent.type(button, '{Enter}');
      clock.tick(0);

      expect(didSubmit).to.be.true();
      expect(button.hasAttribute('disabled')).to.be.true();
    });
  });

  it('does not show spinner if form is invalid', async () => {
    const wrapper = createWrapper({ tagName: 'button', inForm: true });
    const form = wrapper.closest('form')!;
    const input = document.createElement('input');
    input.required = true;
    form.appendChild(input);
    const button = screen.getByRole('button', { name: 'Click Me' });

    await userEvent.type(button, '{Enter}');

    expect(wrapper.classList.contains('spinner-button--spinner-active')).to.be.false();
  });

  it('announces action message', async () => {
    const wrapper = createWrapper({ actionMessage: 'Verifying...' });
    const status = getByRole(wrapper, 'status');
    const button = screen.getByRole('link', { name: 'Click Me' });

    expect(status.textContent).to.be.empty();

    await userEvent.click(button);

    expect(status.textContent).to.equal('Verifying...');
    expect(status.classList.contains('usa-sr-only')).to.be.true();
  });

  it('shows action message visually after long delay', async () => {
    const wrapper = createWrapper({ actionMessage: 'Verifying...' });
    const status = getByRole(wrapper, 'status');
    const button = screen.getByRole('link', { name: 'Click Me' });

    expect(status.textContent).to.be.empty();

    await userEvent.click(button);
    clock.tick(longWaitDurationMs - 1);
    expect(status.classList.contains('usa-sr-only')).to.be.true();
    clock.tick(1);
    expect(status.classList.contains('usa-sr-only')).to.be.false();
  });

  it('supports external dispatched events to control spinner', () => {
    const wrapper = createWrapper();

    fireEvent(wrapper, new window.CustomEvent('spinner.start'));
    expect(wrapper.classList.contains('spinner-button--spinner-active')).to.be.true();
    fireEvent(wrapper, new window.CustomEvent('spinner.stop'));
    expect(wrapper.classList.contains('spinner-button--spinner-active')).to.be.false();
  });

  it('supports disabling default spin on click behavior', async () => {
    const wrapper = createWrapper({ spinOnClick: false });
    const button = screen.getByRole('link', { name: 'Click Me' });

    await userEvent.click(button);

    expect(wrapper.classList.contains('spinner-button--spinner-active')).to.be.false();
  });

  it('removes action message timeout when disconnected from the page', async () => {
    const wrapper = createWrapper({ actionMessage: 'Verifying...' });
    const button = screen.getByRole('link', { name: 'Click Me' });

    sandbox.spy(window, 'setTimeout');
    sandbox.spy(window, 'clearTimeout');

    await userEvent.click(button);
    wrapper.parentNode!.removeChild(wrapper);

    const timeoutId = (window.setTimeout as unknown as SinonStub).getCall(0).returnValue;
    expect(window.clearTimeout).to.have.been.calledWith(timeoutId);
  });
});
