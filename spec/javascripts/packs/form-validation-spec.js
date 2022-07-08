import { screen } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { initialize } from '../../../app/javascript/packs/form-validation';

describe('form-validation', () => {
  it('checks validity of inputs', async () => {
    document.body.innerHTML = `
      <form>
        <input type="text" aria-label="not required field">
        <input type="text" aria-label="required field" required class="field">
      </form>`;

    initialize(document.querySelector('form'));

    const notRequiredField = screen.getByLabelText('not required field');
    await userEvent.type(notRequiredField, 'a{Backspace}');
    expect(notRequiredField.validationMessage).to.be.empty();

    const requiredField = screen.getByLabelText('required field');
    await userEvent.type(requiredField, 'a{Backspace}');
    expect(requiredField.validationMessage).to.equal('simple_form.required.text');
    await userEvent.type(requiredField, 'a');
    expect(notRequiredField.validationMessage).to.be.empty();
  });

  it('resets its own custom validity message on input', async () => {
    document.body.innerHTML = `
      <form>
        <input type="text" aria-label="required field" required class="field">
      </form>`;

    const form = document.querySelector('form');
    initialize(form);

    form.checkValidity();

    const input = screen.getByLabelText('required field');
    await userEvent.type(input, 'a');

    expect(input.validity.customError).to.be.false();
  });

  it('does not reset external custom validity message on input', async () => {
    document.body.innerHTML = `
      <form>
        <input type="text" aria-label="field" class="field">
      </form>`;

    const form = document.querySelector('form');
    initialize(form);

    form.checkValidity();

    /** @type {HTMLInputElement} */
    const input = screen.getByLabelText('field');
    input.setCustomValidity('custom error');

    await userEvent.type(input, 'a');

    expect(input.validity.customError).to.be.true();
  });
});
