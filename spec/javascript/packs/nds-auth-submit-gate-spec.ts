import { initialize } from '../../../app/javascript/packs/nds-auth-submit-gate';

describe('nds-auth-submit-gate', () => {
  afterEach(() => {
    document.body.innerHTML = '';
  });

  const buildForm = () => {
    document.body.innerHTML = `
      <form data-nds-submit-gate>
        <input type="email" name="email" required placeholder=" " />
        <input type="password" name="password" required placeholder=" " />
        <button type="submit">Sign in</button>
      </form>
    `;
    return {
      form: document.querySelector('form')!,
      email: document.querySelector<HTMLInputElement>('input[type=email]')!,
      password: document.querySelector<HTMLInputElement>('input[type=password]')!,
      submit: document.querySelector<HTMLButtonElement>('button[type=submit]')!,
    };
  };

  it('disables the submit button while required fields are empty', () => {
    const { submit } = buildForm();

    initialize();

    expect(submit.disabled).to.be.true();
  });

  it('enables the submit button once email and password are filled', () => {
    const { email, password, submit } = buildForm();

    initialize();

    email.value = 'user@example.com';
    email.dispatchEvent(new Event('input', { bubbles: true }));
    password.value = 'sup3r-secret';
    password.dispatchEvent(new Event('input', { bubbles: true }));

    expect(submit.disabled).to.be.false();
  });

  it('ignores forms without the gate hook', () => {
    document.body.innerHTML = `
      <form>
        <input type="email" required />
        <button type="submit">Sign in</button>
      </form>
    `;
    const submit = document.querySelector<HTMLButtonElement>('button[type=submit]')!;

    initialize();

    expect(submit.disabled).to.be.false();
  });
});
