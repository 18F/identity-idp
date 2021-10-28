import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
import ButtonTo from '@18f/identity-document-capture/components/button-to';
import { UploadContextProvider } from '@18f/identity-document-capture';
import { render } from '../../../support/document-capture';

describe('document-capture/components/button-to', () => {
  it('renders props passed through to Button', () => {
    const { getByRole } = render(
      <ButtonTo url="" method="" isUnstyled>
        Click me
      </ButtonTo>,
    );

    const button = getByRole('button', { name: 'Click me' });

    expect(button.type).to.equal('button');
    expect(button.classList.contains('usa-button')).to.be.true();
    expect(button.classList.contains('usa-button--unstyled')).to.be.true();
  });

  it('creates a form in the body outside the root container', () => {
    const { container } = render(
      <UploadContextProvider csrf="token-value">
        <ButtonTo url="/" method="delete" isUnstyled>
          Click me
        </ButtonTo>
      </UploadContextProvider>,
    );

    const form = document.querySelector('form');
    expect(form).to.be.ok();
    expect(Object.fromEntries(new window.FormData(form))).to.deep.equal({
      _method: 'delete',
      authenticity_token: 'token-value',
    });
    expect(container.contains(form)).to.be.false();
  });

  it('submits to form on click', () => {
    const { getByRole } = render(
      <ButtonTo url="" method="" isUnstyled>
        Click me
      </ButtonTo>,
    );

    const form = document.querySelector('form');
    sinon.stub(form, 'submit');

    userEvent.click(getByRole('button'));

    expect(form.submit).to.have.been.calledOnce();
  });
});
