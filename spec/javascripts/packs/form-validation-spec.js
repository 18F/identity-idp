import { screen } from '@testing-library/dom';
import { initialize } from '../../../app/javascript/packs/form-validation';

describe('form-validation', () => {
  const onSubmit = (event) => event.preventDefault();

  beforeEach(() => {
    window.addEventListener('submit', onSubmit);
  });

  afterEach(() => {
    window.removeEventListener('submit', onSubmit);
  });

  it('adds active, disabled effect to submit buttons on submit', () => {
    document.body.innerHTML = `
      <form>
        <button>Submit1</button>
        <button type="submit">Submit2</button>
        <button type="button">Button1</button>
        <input type="submit" value="Submit3"></form>
        <input value="Input1"></form>
      </form>`;

    const submit1 = screen.getByText('Submit1');
    const submit2 = screen.getByText('Submit2');
    const submit3 = screen.getByText('Submit3');
    const button1 = screen.getByText('Button1');
    const input1 = screen.getByDisplayValue('Input1');

    const form = submit1.closest('form');
    initialize(form);
    submit1.click();

    expect(submit1.disabled).to.be.true();
    expect(submit1.classList.contains('usa-button--active')).to.be.true();
    expect(submit2.disabled).to.be.true();
    expect(submit2.classList.contains('usa-button--active')).to.be.true();
    expect(submit3.disabled).to.be.true();
    expect(submit3.classList.contains('usa-button--active')).to.be.true();
    expect(button1.disabled).to.be.false();
    expect(button1.classList.contains('usa-button--active')).to.be.false();
    expect(input1.disabled).to.be.false();
    expect(input1.classList.contains('usa-button--active')).to.be.false();
  });
});
