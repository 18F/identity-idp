import sinon from 'sinon';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import ButtonTo from './button-to';

describe('ButtonTo', () => {
  beforeEach(() => {
    const csrf = document.createElement('meta');
    csrf.name = 'csrf-token';
    csrf.content = 'token-value';
    document.body.appendChild(csrf);
  });

  it('renders props passed through to Button', () => {
    const { getByRole } = render(
      <ButtonTo url="" method="" isUnstyled>
        Click me
      </ButtonTo>,
    );

    const button = getByRole('button', { name: 'Click me' }) as HTMLButtonElement;

    expect(button.type).to.equal('button');
    expect(button.classList.contains('usa-button')).to.be.true();
    expect(button.classList.contains('usa-button--unstyled')).to.be.true();
  });

  it('creates a form in the body outside the root container', () => {
    const { container, getByRole } = render(
      <ButtonTo url="/" method="delete" isUnstyled>
        Click me
      </ButtonTo>,
    );

    const form = document.querySelector('form')!;
    expect(form).to.be.ok();
    expect(container.contains(form)).to.be.false();
    return Promise.all([
      new Promise<void>((resolve) => {
        form.addEventListener('submit', (event) => {
          event.preventDefault();
          expect(Object.fromEntries(new window.FormData(form))).to.deep.equal({
            _method: 'delete',
            authenticity_token: 'token-value',
          });
          resolve();
        });
      }),
      userEvent.click(getByRole('button')),
    ]);
  });

  it('submits to form on click', async () => {
    const { getByRole } = render(
      <ButtonTo url="" method="" isUnstyled>
        Click me
      </ButtonTo>,
    );

    const form = document.querySelector('form')!;
    sinon.stub(form, 'submit');

    await userEvent.click(getByRole('button'));

    expect(form.submit).to.have.been.calledOnce();
  });
});
