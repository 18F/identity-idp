import { screen } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import './submit-button-element';

describe('SubmitButtonElement', () => {
  it('gracefully ignores if there is no associated form', () => {
    document.body.innerHTML = `
      <lg-submit-button>
        <button class="usa-button">Submit</button>
      </lg-submit-button>`;
  });

  it('activates on form submit', async () => {
    document.body.innerHTML = `
      <form>
        <lg-submit-button>
          <button class="usa-button">Submit</button>
        </lg-submit-button>
      </form>`;

    const button = screen.getByRole('button') as HTMLButtonElement;
    const form = button.closest('form') as HTMLFormElement;
    form.addEventListener('submit', (event) => event.preventDefault());

    await userEvent.click(button);

    expect(button.disabled).to.be.true();
    expect(button.classList.contains('usa-button--active')).to.be.true();
  });

  it('does not activate if form validation prevents submission', async () => {
    document.body.innerHTML = `
      <form>
        <input required>
        <lg-submit-button>
          <button class="usa-button">Submit</button>
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
