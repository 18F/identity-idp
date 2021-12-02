import { screen } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { useSandbox } from '../support/sinon';
import { initialize } from '../../../app/javascript/packs/form-validation';

describe('form-validation', () => {
  const sandbox = useSandbox();

  const onSubmit = (event) => event.preventDefault();

  beforeEach(() => {
    window.addEventListener('submit', onSubmit);
    window.LoginGov = {
      I18n: {
        t: sandbox.stub().returnsArg(0),
        key: sandbox.stub().returnsArg(0),
      },
    };
  });

  afterEach(() => {
    window.removeEventListener('submit', onSubmit);
    delete window.LoginGov;
  });

  it('disables submit buttons on submit', () => {
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
    expect(submit2.disabled).to.be.true();
    expect(submit3.disabled).to.be.true();
    expect(button1.disabled).to.be.false();
    expect(input1.disabled).to.be.false();
  });

  it('checks validity of inputs', async () => {
    document.body.innerHTML = `
      <form>
        <input type="text" aria-label="not required field">
        <input type="text" aria-label="required field" required class="field">
        <input type="text" aria-label="format" pattern="\\\\A\\\\d{5}(-?\\\\d{4})?\\\\z">
        <input type="text" aria-label="format unknown field" pattern="\\\\A\\\\d{5}(-?\\\\d{4})?\\\\z" class="field">
        <input type="text" aria-label="format field" pattern="(?:[a-zA-Z0-9]{4}([ -])?){3}[a-zA-Z0-9]{4}" class="field personal-key">
      </form>`;

    initialize(document.querySelector('form'));

    const notRequiredField = screen.getByLabelText('not required field');
    await userEvent.type(notRequiredField, 'a{backspace}');
    expect(notRequiredField.validationMessage).to.be.empty();

    const requiredField = screen.getByLabelText('required field');
    await userEvent.type(requiredField, 'a{backspace}');
    expect(requiredField.validationMessage).to.equal('simple_form.required.text');
    await userEvent.type(requiredField, 'a');
    expect(notRequiredField.validationMessage).to.be.empty();

    const format = screen.getByLabelText('format');
    await userEvent.type(format, 'a');
    expect(format.validationMessage).to.not.be.empty.and.not.match(
      /^idv\.errors\.pattern_mismatch\./,
    );

    const formatUnknownField = screen.getByLabelText('format unknown field');
    await userEvent.type(formatUnknownField, 'a');
    expect(formatUnknownField.validationMessage).to.not.be.empty.and.not.match(
      /^idv\.errors\.pattern_mismatch\./,
    );

    const formatField = screen.getByLabelText('format field');
    await userEvent.type(formatField, 'a');
    expect(formatField.validationMessage).to.equal('idv.errors.pattern_mismatch.personal_key');
    await userEvent.type(formatField, 'aaa-aaaa-aaaa-aaaa');
    expect(formatField.validationMessage).to.be.empty();
  });

  it('resets its own custom validity message on input', () => {
    document.body.innerHTML = `
      <form>
        <input type="text" aria-label="required field" required class="field">
        <button>Submit</button>
      </form>`;

    const form = document.querySelector('form');
    initialize(form);

    form.checkValidity();

    const input = screen.getByLabelText('required field');
    userEvent.type(input, 'a');

    expect(input.validity.customError).to.be.false();
  });

  it('does not reset external custom validity message on input', () => {
    document.body.innerHTML = `
      <form>
        <input type="text" aria-label="field" class="field">
        <button>Submit</button>
      </form>`;

    const form = document.querySelector('form');
    initialize(form);

    form.checkValidity();

    /** @type {HTMLInputElement} */
    const input = screen.getByLabelText('field');
    input.setCustomValidity('custom error');

    userEvent.type(input, 'a');

    expect(input.validity.customError).to.be.true();
  });
});
