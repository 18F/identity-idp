import { mock } from 'node:test';
import { screen } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import './submit-button-element';

describe('SubmitButtonElement', () => {
  it('gracefully ignores if there is no associated form', () => {
    document.body.innerHTML = `
      <lg-submit-button>
        <button>Submit</button>
      </lg-submit-button>`;
  });

  it('activates on form submit', async () => {
    document.body.innerHTML = `
      <form>
        <lg-submit-button>
          <button>Submit</button>
        </lg-submit-button>
      </form>`;

    const button = screen.getByRole('button') as HTMLButtonElement;
    const form = button.closest('form') as HTMLFormElement;
    form.addEventListener('submit', (event) => event.preventDefault());

    await userEvent.click(button);

    expect(button.ariaDisabled).to.equal('true');
    expect(button.classList.contains('usa-button--active')).to.be.true();
  });

  it('prevents duplicate submissions', async () => {
    document.body.innerHTML = `
      <form>
        <lg-submit-button>
          <button>Submit</button>
        </lg-submit-button>
      </form>`;

    const button = screen.getByRole('button') as HTMLButtonElement;
    const form = button.closest('form') as HTMLFormElement;
    const onSubmit = mock.fn((event: SubmitEvent) => event.preventDefault());
    form.addEventListener('submit', onSubmit);

    await userEvent.click(button);
    expect(onSubmit.mock.callCount()).to.equal(1);
    await userEvent.click(button);
    expect(onSubmit.mock.callCount()).to.equal(1);
  });

  it('does not activate if form validation prevents submission', async () => {
    document.body.innerHTML = `
      <form>
        <input required>
        <lg-submit-button>
          <button>Submit</button>
        </lg-submit-button>
      </form>`;

    const button = screen.getByRole('button') as HTMLButtonElement;
    const form = button.closest('form') as HTMLFormElement;
    form.addEventListener('submit', (event) => event.preventDefault());

    await userEvent.click(button);

    expect(button.disabled).to.be.false();
    expect(button.classList.contains('usa-button--active')).to.be.false();
  });
});
